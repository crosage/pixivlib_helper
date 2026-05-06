#include "flutter_window.h"

#include <cstring>
#include <flutter/standard_method_codec.h>
#include <gdiplus.h>
#include <objidl.h>

#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

std::wstring BuildClipboardErrorMessage(const wchar_t* message) {
  const auto error_code = ::GetLastError();
  if (error_code == ERROR_SUCCESS) {
    return std::wstring(message);
  }

  LPWSTR buffer = nullptr;
  const auto length = ::FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM |
          FORMAT_MESSAGE_IGNORE_INSERTS,
      nullptr, error_code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
      reinterpret_cast<LPWSTR>(&buffer), 0, nullptr);
  std::wstring full_message(message);
  if (length > 0 && buffer != nullptr) {
    full_message.append(L": ");
    full_message.append(buffer, length);
    while (!full_message.empty() &&
           (full_message.back() == L'\r' || full_message.back() == L'\n')) {
      full_message.pop_back();
    }
  }
  if (buffer != nullptr) {
    ::LocalFree(buffer);
  }
  return full_message;
}

HGLOBAL CreateMoveableGlobalMemory(const void* data,
                                   SIZE_T size,
                                   std::wstring* error) {
  HGLOBAL handle = ::GlobalAlloc(GMEM_MOVEABLE, size);
  if (handle == nullptr) {
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(L"Failed to allocate clipboard data");
    }
    return nullptr;
  }

  void* memory = ::GlobalLock(handle);
  if (memory == nullptr) {
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(L"Failed to lock clipboard data");
    }
    ::GlobalFree(handle);
    return nullptr;
  }

  std::memcpy(memory, data, size);
  ::GlobalUnlock(handle);
  return handle;
}

bool DecodeBitmapFromBytes(const std::vector<uint8_t>& encoded_bytes,
                           std::unique_ptr<Gdiplus::Bitmap>* bitmap,
                           std::wstring* error) {
  if (encoded_bytes.empty()) {
    if (error != nullptr) {
      *error = L"Image data is empty.";
    }
    return false;
  }

  HGLOBAL encoded_handle =
      CreateMoveableGlobalMemory(encoded_bytes.data(),
                                 static_cast<SIZE_T>(encoded_bytes.size()),
                                 error);
  if (encoded_handle == nullptr) {
    return false;
  }

  IStream* stream = nullptr;
  const HRESULT stream_result =
      ::CreateStreamOnHGlobal(encoded_handle, TRUE, &stream);
  if (FAILED(stream_result) || stream == nullptr) {
    if (error != nullptr) {
      *error = L"Failed to create image stream.";
    }
    ::GlobalFree(encoded_handle);
    return false;
  }

  std::unique_ptr<Gdiplus::Bitmap> decoded_bitmap(
      Gdiplus::Bitmap::FromStream(stream, FALSE));
  stream->Release();

  if (!decoded_bitmap || decoded_bitmap->GetLastStatus() != Gdiplus::Ok) {
    if (error != nullptr) {
      *error = L"Failed to decode image for clipboard.";
    }
    return false;
  }

  *bitmap = std::move(decoded_bitmap);
  return true;
}

HGLOBAL CreateClipboardDibHandle(Gdiplus::Bitmap& source_bitmap,
                                 std::wstring* error) {
  const UINT width = source_bitmap.GetWidth();
  const UINT height = source_bitmap.GetHeight();
  if (width == 0 || height == 0) {
    if (error != nullptr) {
      *error = L"Decoded image has invalid dimensions.";
    }
    return nullptr;
  }

  Gdiplus::Bitmap bitmap(width, height, PixelFormat32bppARGB);
  Gdiplus::Graphics graphics(&bitmap);
  if (graphics.DrawImage(const_cast<Gdiplus::Bitmap*>(&source_bitmap), 0, 0,
                         width, height) != Gdiplus::Ok) {
    if (error != nullptr) {
      *error = L"Failed to rasterize image for clipboard.";
    }
    return nullptr;
  }

  Gdiplus::Rect rect(0, 0, static_cast<INT>(width), static_cast<INT>(height));
  Gdiplus::BitmapData bitmap_data{};
  if (bitmap.LockBits(&rect, Gdiplus::ImageLockModeRead, PixelFormat32bppARGB,
                      &bitmap_data) != Gdiplus::Ok) {
    if (error != nullptr) {
      *error = L"Failed to lock image pixels for clipboard.";
    }
    return nullptr;
  }

  const SIZE_T row_bytes = static_cast<SIZE_T>(width) * 4;
  const SIZE_T pixel_bytes = row_bytes * static_cast<SIZE_T>(height);
  const SIZE_T total_bytes = sizeof(BITMAPINFOHEADER) + pixel_bytes;

  HGLOBAL dib_handle = ::GlobalAlloc(GMEM_MOVEABLE, total_bytes);
  if (dib_handle == nullptr) {
    bitmap.UnlockBits(&bitmap_data);
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(
          L"Failed to allocate DIB clipboard data");
    }
    return nullptr;
  }

  auto* dib_memory = static_cast<unsigned char*>(::GlobalLock(dib_handle));
  if (dib_memory == nullptr) {
    bitmap.UnlockBits(&bitmap_data);
    if (error != nullptr) {
      *error =
          BuildClipboardErrorMessage(L"Failed to lock DIB clipboard data");
    }
    ::GlobalFree(dib_handle);
    return nullptr;
  }

  auto* header = reinterpret_cast<BITMAPINFOHEADER*>(dib_memory);
  header->biSize = sizeof(BITMAPINFOHEADER);
  header->biWidth = static_cast<LONG>(width);
  header->biHeight = static_cast<LONG>(height);
  header->biPlanes = 1;
  header->biBitCount = 32;
  header->biCompression = BI_RGB;
  header->biSizeImage = static_cast<DWORD>(pixel_bytes);
  header->biXPelsPerMeter = 0;
  header->biYPelsPerMeter = 0;
  header->biClrUsed = 0;
  header->biClrImportant = 0;

  auto* destination_pixels = dib_memory + sizeof(BITMAPINFOHEADER);
  auto* source_pixels = static_cast<const unsigned char*>(bitmap_data.Scan0);
  const UINT stride = static_cast<UINT>(
      bitmap_data.Stride < 0 ? -bitmap_data.Stride : bitmap_data.Stride);

  for (UINT row = 0; row < height; ++row) {
    const UINT source_row_index =
        bitmap_data.Stride < 0 ? row : (height - 1 - row);
    const auto* source_row = source_pixels + source_row_index * stride;
    auto* destination_row = destination_pixels + row * row_bytes;
    std::memcpy(destination_row, source_row, row_bytes);
  }

  ::GlobalUnlock(dib_handle);
  bitmap.UnlockBits(&bitmap_data);
  return dib_handle;
}

HGLOBAL CreateClipboardPngHandle(const std::vector<uint8_t>& encoded_bytes,
                                 std::wstring* error) {
  return CreateMoveableGlobalMemory(
      encoded_bytes.data(),
      static_cast<SIZE_T>(encoded_bytes.size()),
      error);
}

bool CopyImageBytesToClipboard(HWND window,
                               const std::vector<uint8_t>& encoded_bytes,
                               std::wstring* error) {
  std::unique_ptr<Gdiplus::Bitmap> bitmap;
  if (!DecodeBitmapFromBytes(encoded_bytes, &bitmap, error)) {
    return false;
  }

  HGLOBAL dib_handle = CreateClipboardDibHandle(*bitmap, error);
  if (dib_handle == nullptr) {
    return false;
  }

  HGLOBAL png_handle = CreateClipboardPngHandle(encoded_bytes, error);
  if (png_handle == nullptr) {
    ::GlobalFree(dib_handle);
    return false;
  }

  if (!::OpenClipboard(window)) {
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(L"Failed to open clipboard");
    }
    ::GlobalFree(dib_handle);
    ::GlobalFree(png_handle);
    return false;
  }

  if (!::EmptyClipboard()) {
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(L"Failed to clear clipboard");
    }
    ::CloseClipboard();
    ::GlobalFree(dib_handle);
    ::GlobalFree(png_handle);
    return false;
  }

  if (::SetClipboardData(CF_DIB, dib_handle) == nullptr) {
    if (error != nullptr) {
      *error = BuildClipboardErrorMessage(L"Failed to set DIB clipboard image");
    }
    ::CloseClipboard();
    ::GlobalFree(dib_handle);
    ::GlobalFree(png_handle);
    return false;
  }

  dib_handle = nullptr;

  const UINT png_format = ::RegisterClipboardFormatW(L"PNG");
  if (png_format != 0 && ::SetClipboardData(png_format, png_handle) != nullptr) {
    png_handle = nullptr;
  }

  ::CloseClipboard();
  if (png_handle != nullptr) {
    ::GlobalFree(png_handle);
  }
  return true;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  Gdiplus::GdiplusStartupInput gdiplus_startup_input;
  if (Gdiplus::GdiplusStartup(&gdiplus_token_, &gdiplus_startup_input,
                              nullptr) != Gdiplus::Ok) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    if (gdiplus_token_ != 0) {
      Gdiplus::GdiplusShutdown(gdiplus_token_);
      gdiplus_token_ = 0;
    }
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  RegisterImageClipboardChannel();
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  image_clipboard_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }
  if (gdiplus_token_ != 0) {
    Gdiplus::GdiplusShutdown(gdiplus_token_);
    gdiplus_token_ = 0;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::RegisterImageClipboardChannel() {
  image_clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "tagselector/image_clipboard",
          &flutter::StandardMethodCodec::GetInstance());

  image_clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "copyImage") {
          result->NotImplemented();
          return;
        }

        const auto* arguments = call.arguments();
        const auto* bytes = arguments == nullptr
                                ? nullptr
                                : std::get_if<std::vector<uint8_t>>(arguments);
        if (bytes == nullptr || bytes->empty()) {
          result->Error("invalid-arguments", "Image bytes are required.");
          return;
        }

        std::wstring error;
        if (!CopyImageBytesToClipboard(GetHandle(), *bytes, &error)) {
          result->Error("clipboard-error", Utf8FromUtf16(error.c_str()));
          return;
        }

        result->Success(flutter::EncodableValue(true));
      });
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
