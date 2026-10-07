package com.flixgo.myapp

import android.content.ContentValues
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flixgo/media")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToGallery") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val name = call.argument<String>("name")
                val mime = call.argument<String>("mime")
                val audio = call.argument<Boolean>("audio") ?: false
                if (path == null || name == null || mime == null) {
                    result.error("ARGS", "Missing arguments", null)
                    return@setMethodCallHandler
                }
                Thread {
                    try {
                        val saved = saveMedia(File(path), name, mime, audio)
                        runOnUiThread { result.success(saved) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("SAVE", e.message, null) }
                    }
                }.start()
            }
    }

    private fun saveMedia(src: File, name: String, mime: String, audio: Boolean): String {
        val folder = if (audio) Environment.DIRECTORY_MUSIC else Environment.DIRECTORY_MOVIES

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val collection = if (audio) {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            }
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                put(MediaStore.MediaColumns.MIME_TYPE, mime)
                put(MediaStore.MediaColumns.RELATIVE_PATH, "$folder/FlixGo")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(collection, values)
                ?: throw Exception("Could not create media entry")
            try {
                val out = resolver.openOutputStream(uri)
                    ?: throw Exception("Could not open output stream")
                out.use { o ->
                    FileInputStream(src).use { input -> input.copyTo(o) }
                }
                val done = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, done, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            return uri.toString()
        } else {
            val dir = File(Environment.getExternalStoragePublicDirectory(folder), "FlixGo")
            dir.mkdirs()
            val dest = File(dir, name)
            src.copyTo(dest, overwrite = true)
            MediaScannerConnection.scanFile(
                this, arrayOf(dest.absolutePath), arrayOf(mime), null
            )
            return dest.absolutePath
        }
    }
}