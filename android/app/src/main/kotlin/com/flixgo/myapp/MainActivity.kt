package com.flixgo.myapp

import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flixgo/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToGallery" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name")
                        val mime = call.argument<String>("mime")
                        val audio = call.argument<Boolean>("audio") ?: false
                        if (path == null || name == null || mime == null) {
                            result.error("ARGS", "Missing arguments", null)
                        } else {
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
                    "open" -> {
                        val uri = call.argument<String>("uri")
                        val mime = call.argument<String>("mime")
                        result.success(
                            if (uri == null || mime == null) false else openMedia(uri, mime)
                        )
                    }
                    "share" -> {
                        val uri = call.argument<String>("uri")
                        val mime = call.argument<String>("mime")
                        result.success(
                            if (uri == null || mime == null) false else shareMedia(uri, mime)
                        )
                    }
                    "delete" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.success(false)
                        } else {
                            Thread {
                                val ok = deleteMedia(uri)
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    "exists" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.success(false)
                        } else {
                            Thread {
                                val ok = mediaExists(uri)
                                runOnUiThread { result.success(ok) }
                            }.start()
                        }
                    }
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
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
            var scanned: String? = null
            val latch = CountDownLatch(1)
            MediaScannerConnection.scanFile(
                this, arrayOf(dest.absolutePath), arrayOf(mime)
            ) { _, uri ->
                scanned = uri?.toString()
                latch.countDown()
            }
            latch.await(5, TimeUnit.SECONDS)
            return scanned ?: dest.absolutePath
        }
    }

    private fun openMedia(uriStr: String, mime: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(uriStr), mime)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun shareMedia(uriStr: String, mime: String): Boolean {
        return try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = mime
                putExtra(Intent.EXTRA_STREAM, Uri.parse(uriStr))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(send, null))
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun deleteMedia(uriStr: String): Boolean {
        return try {
            contentResolver.delete(Uri.parse(uriStr), null, null) > 0
        } catch (e: Exception) {
            false
        }
    }

    private fun mediaExists(uriStr: String): Boolean {
        return try {
            val cursor = contentResolver.query(
                Uri.parse(uriStr),
                arrayOf(MediaStore.MediaColumns._ID),
                null, null, null
            )
            cursor?.use { it.count > 0 } ?: false
        } catch (e: Exception) {
            false
        }
    }
}