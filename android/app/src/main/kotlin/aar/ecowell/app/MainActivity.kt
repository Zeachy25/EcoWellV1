package aar.ecowell.app

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var progressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROGRESS_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
            }

            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadAndInstallRelease" -> {
                    val url = call.argument<String>("url")
                    if (url == null || !isAllowedDownloadUrl(url)) {
                        result.error("invalid_url", "Invalid APK download URL.", null)
                    } else if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        !packageManager.canRequestPackageInstalls()
                    ) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                            result.error(
                                "install_permission_required",
                                "Allow EcoWell to install apps, then return and continue.",
                                null,
                            )
                        } catch (error: Exception) {
                            result.error(
                                "settings_unavailable",
                                "Could not open Android install permission settings.",
                                error.message,
                            )
                        }
                    } else {
                        downloadRelease(url, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isAllowedDownloadUrl(value: String): Boolean {
        return try {
            val uri = Uri.parse(value)
            uri.scheme == "https" && uri.host in ALLOWED_DOWNLOAD_HOSTS
        } catch (_: Exception) {
            false
        }
    }

    private fun downloadRelease(value: String, result: MethodChannel.Result) {
        Thread {
            val updateDirectory = File(cacheDir, "updates")
            val partialFile = File(updateDirectory, "ecowell-update.apk.part")
            val apkFile = File(updateDirectory, "ecowell-update.apk")
            try {
                if (!updateDirectory.exists() && !updateDirectory.mkdirs()) {
                    throw IOException("Could not create the update cache directory.")
                }
                partialFile.delete()
                val totalBytes = downloadApk(value, partialFile)
                if (partialFile.length() <= 0L) {
                    throw IOException("The downloaded APK is empty.")
                }
                if (apkFile.exists() && !apkFile.delete()) {
                    throw IOException("Could not replace the cached APK.")
                }
                if (!partialFile.renameTo(apkFile)) {
                    throw IOException("Could not save the downloaded APK.")
                }

                mainHandler.post {
                    try {
                        val contentUri = FileProvider.getUriForFile(
                            this,
                            "$packageName.releaseupdates",
                            apkFile,
                        )
                        val installIntent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(
                                contentUri,
                                "application/vnd.android.package-archive",
                            )
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            clipData = ClipData.newRawUri("EcoWell update", contentUri)
                        }
                        if (installIntent.resolveActivity(packageManager) == null) {
                            throw IOException("No Android package installer is available.")
                        }
                        startActivity(installIntent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error(
                            "installer_failed",
                            error.message ?: "Could not open the Android installer.",
                            null,
                        )
                    }
                }
            } catch (error: Exception) {
                partialFile.delete()
                mainHandler.post {
                    result.error(
                        "download_failed",
                        error.message ?: "Could not download the APK.",
                        null,
                    )
                }
            }
        }.start()
    }

    private fun downloadApk(value: String, output: File): Long {
        var currentUrl = URL(value)
        var connection: HttpURLConnection? = null
        try {
            repeat(MAX_REDIRECTS + 1) { redirectCount ->
                if (currentUrl.protocol != "https" ||
                    currentUrl.host !in ALLOWED_DOWNLOAD_HOSTS
                ) {
                    throw IOException("APK download redirected to an untrusted host.")
                }

                connection = (currentUrl.openConnection() as HttpURLConnection).apply {
                    instanceFollowRedirects = false
                    connectTimeout = CONNECT_TIMEOUT_MS
                    readTimeout = READ_TIMEOUT_MS
                    requestMethod = "GET"
                }
                val responseCode = connection!!.responseCode
                if (responseCode in 300..399) {
                    val location = connection!!.getHeaderField("Location")
                        ?: throw IOException("APK download returned an invalid redirect.")
                    connection!!.disconnect()
                    connection = null
                    if (redirectCount == MAX_REDIRECTS) {
                        throw IOException("APK download exceeded the redirect limit.")
                    }
                    currentUrl = URL(currentUrl, location)
                } else {
                    if (responseCode != HttpURLConnection.HTTP_OK) {
                        throw IOException("APK download failed (HTTP $responseCode).")
                    }
                    val totalBytes = connection!!.contentLengthLong
                    connection!!.inputStream.use { input ->
                        output.outputStream().buffered().use { stream ->
                            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                            var received = 0L
                            while (true) {
                                val count = input.read(buffer)
                                if (count < 0) break
                                stream.write(buffer, 0, count)
                                received += count
                                val progressReceived = received
                                val currentTotal = totalBytes
                                mainHandler.post {
                                    progressSink?.success(
                                        mapOf(
                                            "received" to progressReceived,
                                            "total" to currentTotal,
                                        ),
                                    )
                                }
                            }
                        }
                    }
                    return output.length()
                }
            }
            throw IOException("Could not download the APK.")
        } finally {
            connection?.disconnect()
        }
    }

    companion object {
        private const val METHOD_CHANNEL = "aar.ecowell.app/release_update"
        private const val PROGRESS_CHANNEL =
            "aar.ecowell.app/release_update_progress"
        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS = 30_000
        private const val MAX_REDIRECTS = 5
        private val ALLOWED_DOWNLOAD_HOSTS = setOf(
            "github.com",
            "release-assets.githubusercontent.com",
            "objects.githubusercontent.com",
        )
    }
}
