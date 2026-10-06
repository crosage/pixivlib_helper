package com.example.tagselector

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.media.ExifInterface
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.abs

class MainActivity : FlutterActivity() {
    private val mediaStoreChannelName = "tagselector/media_store"
    private val nativeShareChannelName = "tagselector/native_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaStoreChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishImage" -> publishImage(call, result)
                "rewriteImageMetadata" -> rewriteImageMetadata(call, result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            nativeShareChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> shareText(call, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun shareText(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text")
        if (text.isNullOrBlank()) {
            result.error("bad_args", "text is required.", null)
            return
        }

        val title = call.argument<String>("title").orEmpty()
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            if (title.isNotBlank()) {
                putExtra(Intent.EXTRA_SUBJECT, title)
            }
        }
        startActivity(Intent.createChooser(intent, title.ifBlank { "分享作品" }))
        result.success(true)
    }

    private fun publishImage(call: MethodCall, result: MethodChannel.Result) {
        val sourcePath = call.argument<String>("sourcePath")
        if (sourcePath.isNullOrBlank()) {
            result.error("bad_args", "sourcePath is required.", null)
            return
        }

        val sourceFile = File(sourcePath)
        if (!sourceFile.exists() || !sourceFile.isFile) {
            result.error("not_found", "Source image does not exist.", sourcePath)
            return
        }

        val displayName = sanitizeFileName(
            call.argument<String>("displayName") ?: sourceFile.name
        )
        val relativePath = sanitizeRelativePath(
            call.argument<String>("relativePath") ?: "PixivHelper"
        )
        val mimeType = call.argument<String>("mimeType") ?: guessMimeType(displayName)
        val dateTakenMillis = call.argument<Number>("dateTakenMillis")?.toLong()

        try {
            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                publishImageWithMediaStore(
                    sourceFile,
                    displayName,
                    relativePath,
                    mimeType
                )
            } else {
                publishImageLegacy(sourceFile, displayName, relativePath, mimeType, dateTakenMillis)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("publish_failed", error.message, null)
        }
    }

    private fun rewriteImageMetadata(call: MethodCall, result: MethodChannel.Result) {
        val items = call.argument<List<Map<String, Any?>>>("items")
        if (items == null) {
            result.error("bad_args", "items is required.", null)
            return
        }

        Thread {
            try {
                val targets = items.mapIndexed { index, item ->
                    val uriValue = item["uri"] as? String
                        ?: throw IllegalArgumentException("Missing URI for item $index")
                    val dateTakenMillis = (item["dateTakenMillis"] as? Number)?.toLong()
                        ?: throw IllegalArgumentException("Missing date for item $index")
                    resolveMediaDateTarget(Uri.parse(uriValue), dateTakenMillis)
                }
                for (target in targets) {
                    writeImageFileDates(target)
                }
                scanUpdatedImages(targets)
                for (target in targets) {
                    verifyIndexedImageDate(target)
                }
                runOnUiThread { result.success(targets.size) }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error(
                        "metadata_rewrite_failed",
                        "${error.javaClass.simpleName}: ${error.message}",
                        null
                    )
                }
            }
        }.start()
    }

    private data class MediaDateTarget(
        val uri: Uri,
        val file: File,
        val mimeType: String,
        val dateTakenMillis: Long,
        val supportsExif: Boolean
    )

    private fun resolveMediaDateTarget(uri: Uri, dateTakenMillis: Long): MediaDateTarget {
        if (uri.scheme != "content" || uri.authority != MediaStore.AUTHORITY) {
            throw IllegalArgumentException("Expected a MediaStore image URI: $uri")
        }

        val projection = arrayOf(
            MediaStore.Images.Media.DATA,
            MediaStore.Images.Media.MIME_TYPE
        )
        val (path, mimeType) = applicationContext.contentResolver.query(
            uri,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            if (!cursor.moveToFirst()) {
                throw IllegalStateException("Gallery image is missing: $uri")
            }
            val imagePath = cursor.getString(
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.DATA)
            ) ?: throw IllegalStateException("Gallery path is unavailable: $uri")
            val imageMimeType = cursor.getString(
                cursor.getColumnIndexOrThrow(MediaStore.Images.Media.MIME_TYPE)
            ) ?: guessMimeType(imagePath)
            Pair(imagePath, imageMimeType)
        } ?: throw IllegalStateException("Unable to query gallery image: $uri")

        val file = File(path).canonicalFile
        val galleryDirectory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "PixivHelper"
        ).canonicalFile
        if (!file.path.startsWith("${galleryDirectory.path}${File.separator}")) {
            throw SecurityException("Image is outside the PixivHelper gallery folder: $uri")
        }
        if (!file.isFile) {
            throw IllegalStateException("Gallery image file is missing: $uri")
        }

        val supportsExif = when (file.extension.lowercase(Locale.ROOT)) {
            "jpg", "jpeg", "png", "webp" -> true
            else -> false
        }
        return MediaDateTarget(uri, file, mimeType, dateTakenMillis, supportsExif)
    }

    private fun writeImageFileDates(target: MediaDateTarget) {
        if (target.supportsExif) {
            val dateFormat = SimpleDateFormat("yyyy:MM:dd HH:mm:ss", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }
            val exifDate = dateFormat.format(Date(target.dateTakenMillis))
            val exif = ExifInterface(target.file.absolutePath)
            exif.setAttribute(ExifInterface.TAG_DATETIME_ORIGINAL, exifDate)
            exif.setAttribute(ExifInterface.TAG_OFFSET_TIME_ORIGINAL, "+00:00")
            exif.setAttribute(ExifInterface.TAG_DATETIME_DIGITIZED, exifDate)
            exif.setAttribute(ExifInterface.TAG_OFFSET_TIME_DIGITIZED, "+00:00")
            exif.setAttribute(ExifInterface.TAG_DATETIME, exifDate)
            exif.setAttribute(ExifInterface.TAG_OFFSET_TIME, "+00:00")
            exif.saveAttributes()
        }
        if (!target.file.setLastModified(target.dateTakenMillis)) {
            throw IllegalStateException("Unable to set file modification time: ${target.uri}")
        }
    }

    private fun scanUpdatedImages(targets: List<MediaDateTarget>) {
        if (targets.isEmpty()) return
        val remaining = CountDownLatch(targets.size)
        val failures = AtomicInteger(0)
        MediaScannerConnection.scanFile(
            applicationContext,
            targets.map { it.file.absolutePath }.toTypedArray(),
            targets.map { it.mimeType }.toTypedArray()
        ) { _, scannedUri ->
            if (scannedUri == null) failures.incrementAndGet()
            remaining.countDown()
        }
        val timeoutSeconds = (targets.size * 2L).coerceIn(30L, 120L)
        if (!remaining.await(timeoutSeconds, TimeUnit.SECONDS)) {
            throw IllegalStateException("Timed out while refreshing gallery metadata")
        }
        if (failures.get() > 0) {
            throw IllegalStateException("Gallery scan failed for ${failures.get()} images")
        }
    }

    private fun verifyIndexedImageDate(target: MediaDateTarget) {
        val column = if (target.supportsExif) {
            MediaStore.Images.Media.DATE_TAKEN
        } else {
            MediaStore.Images.Media.DATE_MODIFIED
        }
        val indexedDate = applicationContext.contentResolver.query(
            target.uri,
            arrayOf(column),
            null,
            null,
            null
        )?.use { cursor ->
            if (!cursor.moveToFirst()) {
                throw IllegalStateException("Gallery image disappeared: ${target.uri}")
            }
            val columnIndex = cursor.getColumnIndexOrThrow(column)
            if (cursor.isNull(columnIndex)) null else cursor.getLong(columnIndex)
        } ?: throw IllegalStateException("Unable to verify gallery image: ${target.uri}")

        val expectedSeconds = target.dateTakenMillis / 1000
        val actualSeconds = if (target.supportsExif) {
            indexedDate / 1000
        } else {
            indexedDate
        }
        if (abs(actualSeconds - expectedSeconds) > 1) {
            throw IllegalStateException(
                "Gallery date did not update for ${target.uri}: " +
                    "expected $expectedSeconds, got $actualSeconds"
            )
        }
    }

    private fun publishImageWithMediaStore(
        sourceFile: File,
        displayName: String,
        relativePath: String,
        mimeType: String
    ): Uri {
        val resolver = applicationContext.contentResolver
        val collection = MediaStore.Images.Media.getContentUri(
            MediaStore.VOLUME_EXTERNAL_PRIMARY
        )
        val fullRelativePath = "${Environment.DIRECTORY_PICTURES}/$relativePath/"
        val existingUri = findExistingMediaStoreImage(
            collection,
            displayName,
            fullRelativePath
        )
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Images.Media.MIME_TYPE, mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, fullRelativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }

        val uri = existingUri ?: (resolver.insert(collection, values)
            ?: throw IllegalStateException("Unable to create MediaStore item."))

        try {
            if (existingUri != null) {
                resolver.update(uri, values, null, null)
            }

            resolver.openOutputStream(uri, "rwt")?.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Unable to open MediaStore stream.")

            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri
        } catch (error: Exception) {
            if (existingUri == null) {
                resolver.delete(uri, null, null)
            } else {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
            throw error
        }
    }

    private fun findExistingMediaStoreImage(
        collection: Uri,
        displayName: String,
        relativePath: String
    ): Uri? {
        val resolver = applicationContext.contentResolver
        val projection = arrayOf(MediaStore.Images.Media._ID)
        val pathsToTry = listOf(relativePath, relativePath.trimEnd('/'))

        for (path in pathsToTry) {
            resolver.query(
                collection,
                projection,
                "${MediaStore.Images.Media.DISPLAY_NAME}=? AND ${MediaStore.Images.Media.RELATIVE_PATH}=?",
                arrayOf(displayName, path),
                "${MediaStore.Images.Media.DATE_MODIFIED} DESC"
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id = cursor.getLong(
                        cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                    )
                    return ContentUris.withAppendedId(collection, id)
                }
            }
        }

        return null
    }

    private fun publishImageLegacy(
        sourceFile: File,
        displayName: String,
        relativePath: String,
        mimeType: String,
        dateTakenMillis: Long?
    ): Uri {
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            relativePath
        )
        if (!directory.exists() && !directory.mkdirs()) {
            throw IllegalStateException("Unable to create gallery directory.")
        }

        val targetFile = File(directory, displayName)
        FileInputStream(sourceFile).use { input ->
            FileOutputStream(targetFile, false).use { output ->
                input.copyTo(output)
            }
        }
        if (dateTakenMillis != null) {
            targetFile.setLastModified(dateTakenMillis)
        }

        MediaScannerConnection.scanFile(
            applicationContext,
            arrayOf(targetFile.absolutePath),
            arrayOf(mimeType),
            null
        )
        return Uri.fromFile(targetFile)
    }

    private fun sanitizeFileName(value: String): String {
        val sanitized = value
            .replace(Regex("""[\\/:*?"<>|]"""), "_")
            .trim()
        return sanitized.ifBlank { "pixiv_image.jpg" }
    }

    private fun sanitizeRelativePath(value: String): String {
        val segments = value
            .split('/', '\\')
            .map { it.replace(Regex("""[\\/:*?"<>|]"""), "_").trim() }
            .filter { it.isNotEmpty() && it != "." && it != ".." }
        return segments.joinToString("/").ifBlank { "PixivHelper" }
    }

    private fun guessMimeType(displayName: String): String {
        return when (displayName.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "webp" -> "image/webp"
            else -> "image/jpeg"
        }
    }
}
