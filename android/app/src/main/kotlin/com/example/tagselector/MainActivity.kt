package com.example.tagselector

import android.content.ContentUris
import android.content.ContentValues
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

class MainActivity : FlutterActivity() {
    private val mediaStoreChannelName = "tagselector/media_store"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            mediaStoreChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "publishImage" -> publishImage(call, result)
                else -> result.notImplemented()
            }
        }
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
                    mimeType,
                    dateTakenMillis
                )
            } else {
                publishImageLegacy(sourceFile, displayName, relativePath, mimeType, dateTakenMillis)
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("publish_failed", error.message, null)
        }
    }

    private fun publishImageWithMediaStore(
        sourceFile: File,
        displayName: String,
        relativePath: String,
        mimeType: String,
        dateTakenMillis: Long?
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
            putStableMediaDates(dateTakenMillis)
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
            values.putStableMediaDates(dateTakenMillis)
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            return uri
        } catch (error: Exception) {
            if (existingUri == null) {
                resolver.delete(uri, null, null)
            } else {
                values.clear()
                values.putStableMediaDates(dateTakenMillis)
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

    private fun ContentValues.putStableMediaDates(dateTakenMillis: Long?) {
        val millis = dateTakenMillis ?: System.currentTimeMillis()
        put(MediaStore.Images.Media.DATE_TAKEN, millis)
        put(MediaStore.Images.Media.DATE_ADDED, millis / 1000)
        put(MediaStore.Images.Media.DATE_MODIFIED, millis / 1000)
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
