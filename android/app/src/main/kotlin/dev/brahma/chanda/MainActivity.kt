package dev.brahma.chanda

import android.app.KeyguardManager
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Hands chanda:// links to Dart (lib/app/links.dart): the camera app opens
 * them when it scans a pairing QR code. Hands text shared to Chanda (a
 * product link) to Dart too (lib/app/share.dart), and a shared photo as a
 * copy in the app's cache, for search by photo. Also tells Dart the device's name
 * for the pairing request, and what Sentinel asks about the device. A
 * fragment activity, which local_auth needs for the app lock's fingerprint
 * and face prompt.
 */
class MainActivity : FlutterFragmentActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null
    private var shares: MethodChannel? = null
    private var pendingShare: String? = null
    private var pendingPhoto: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = linkOf(intent)
        pendingShare = sharedText(intent)
        pendingPhoto = sharedPhoto(intent)
        shares = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.brahma.chanda/share").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeShared" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    "takePhoto" -> {
                        result.success(pendingPhoto)
                        pendingPhoto = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.brahma.chanda/device").setMethodCallHandler { call, result ->
            if (call.method == "security") result.success(securityFacts()) else result.notImplemented()
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dev.brahma.chanda/links").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeLink" -> {
                        result.success(pending)
                        pending = null
                    }
                    "deviceName" -> result.success(deviceName())
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * What Sentinel reads about the device (core's device_checks.dart): whether
     * a screen lock is set, storage is encrypted, and the newest security patch.
     */
    private fun securityFacts(): Map<String, Any?> {
        val keyguard = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val policy = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val status = policy.storageEncryptionStatus
        return mapOf(
            "screenLock" to keyguard.isDeviceSecure,
            "encrypted" to (status == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE ||
                status == DevicePolicyManager.ENCRYPTION_STATUS_ACTIVE_PER_USER),
            "patched" to Build.VERSION.SECURITY_PATCH.takeIf { it.isNotEmpty() },
        )
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        linkOf(intent)?.let { channel?.invokeMethod("link", it) }
        sharedText(intent)?.let { shares?.invokeMethod("shared", it) }
        sharedPhoto(intent)?.let { shares?.invokeMethod("photo", it) }
    }

    private fun sharedText(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_SEND && it.type == "text/plain" }
            ?.getStringExtra(Intent.EXTRA_TEXT)

    /**
     * Copies a shared picture (up to 15 MB) into the cache, replacing the
     * last one, and returns its path. Null for anything else.
     */
    private fun sharedPhoto(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("image/") != true) return null
        @Suppress("DEPRECATION")
        val uri = (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }) ?: return null
        return try {
            val out = File(cacheDir, "shared-photo")
            contentResolver.openInputStream(uri)?.use { input ->
                out.outputStream().use { output ->
                    val buf = ByteArray(64 * 1024)
                    var total = 0L
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        total += n
                        if (total > 15L * 1024 * 1024) return null
                        output.write(buf, 0, n)
                    }
                }
            } ?: return null
            out.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun linkOf(intent: Intent?): String? =
        intent?.takeIf { it.action == Intent.ACTION_VIEW }?.data?.takeIf { it.scheme == "chanda" }?.toString()

    private fun deviceName(): String {
        val maker = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        val model = Build.MODEL
        return if (model.startsWith(maker, ignoreCase = true)) model else "$maker $model"
    }
}
