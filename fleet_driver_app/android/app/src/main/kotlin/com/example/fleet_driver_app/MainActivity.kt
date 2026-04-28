package com.example.fleet_driver_app

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "fleet_driver_app/app_info"
        ).setMethodCallHandler { call, result ->
            if (call.method != "getAppVersionInfo") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val packageInfo = packageManager.getPackageInfo(packageName, 0)
                val versionCode =
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        packageInfo.longVersionCode.toInt()
                    } else {
                        @Suppress("DEPRECATION")
                        packageInfo.versionCode
                    }

                result.success(
                    mapOf(
                        "versionName" to (packageInfo.versionName ?: ""),
                        "versionCode" to versionCode
                    )
                )
            } catch (error: PackageManager.NameNotFoundException) {
                result.error("package_info_error", error.message, null)
            }
        }
    }
}
