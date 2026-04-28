import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'api_service.dart';

class AppUpdateInfo {
  final String versionName;
  final int versionCode;
  final String changelog;
  final bool forceUpdate;
  final String downloadUrl;

  const AppUpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.changelog,
    required this.forceUpdate,
    required this.downloadUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      versionName: (json["version_name"] ?? "").toString(),
      versionCode: json["version_code"] is int
          ? json["version_code"] as int
          : int.tryParse(json["version_code"]?.toString() ?? "") ?? 0,
      changelog: (json["changelog"] ?? "").toString(),
      forceUpdate: json["force_update"] == true,
      downloadUrl: (json["download_url"] ?? "").toString(),
    );
  }
}

class InstalledAppInfo {
  final String versionName;
  final int versionCode;

  const InstalledAppInfo({
    required this.versionName,
    required this.versionCode,
  });
}

class AppUpdateService {
  static const MethodChannel _channel =
      MethodChannel("fleet_driver_app/app_info");
  static bool _dialogShownThisLaunch = false;

  static Future<InstalledAppInfo?> _getInstalledAppInfo() async {
    if (!Platform.isAndroid) return null;

    try {
      final result =
          await _channel.invokeMethod<Map<Object?, Object?>>("getAppVersionInfo");
      if (result == null) return null;

      final versionName = (result["versionName"] ?? "").toString();
      final versionCode = result["versionCode"] is int
          ? result["versionCode"] as int
          : int.tryParse(result["versionCode"]?.toString() ?? "") ?? 0;

      if (versionCode <= 0) return null;

      return InstalledAppInfo(
        versionName: versionName,
        versionCode: versionCode,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<AppUpdateInfo?> _fetchLatestUpdate() async {
    final response = await ApiService.get("/api/apk/latest");
    if (response.statusCode != 200) return null;

    try {
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      final update = AppUpdateInfo.fromJson(data);
      if (update.versionCode <= 0 || update.downloadUrl.isEmpty) return null;
      return update;
    } catch (_) {
      return null;
    }
  }

  static Future<void> checkAndPrompt(BuildContext context) async {
    if (_dialogShownThisLaunch || !Platform.isAndroid) return;

    final installed = await _getInstalledAppInfo();
    final latest = await _fetchLatestUpdate();

    if (installed == null || latest == null) return;
    if (latest.versionCode <= installed.versionCode) return;
    if (!context.mounted) return;

    _dialogShownThisLaunch = true;
    await _showUpdateDialog(
      context,
      installed: installed,
      latest: latest,
    );
  }

  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required InstalledAppInfo installed,
    required AppUpdateInfo latest,
  }) async {
    bool downloading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !latest.forceUpdate,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> startDownload() async {
              if (downloading) return;

              setDialogState(() => downloading = true);

              final messenger = ScaffoldMessenger.maybeOf(dialogContext);
              messenger?.showSnackBar(
                const SnackBar(content: Text("Downloading update...")),
              );

              final apkFile = await _downloadApk(latest);

              if (!dialogContext.mounted) return;
              setDialogState(() => downloading = false);

              if (apkFile == null) {
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text("Failed to download update"),
                  ),
                );
                return;
              }

              await OpenFilex.open(apkFile.path);

              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
            }

            return AlertDialog(
              title: const Text("Update Available"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Installed: ${installed.versionName} (${installed.versionCode})",
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Latest: ${latest.versionName} (${latest.versionCode})",
                  ),
                  if (latest.changelog.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      "What's new",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(latest.changelog.trim()),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    "Android will ask for confirmation before installing the update.",
                  ),
                ],
              ),
              actions: [
                if (!latest.forceUpdate)
                  TextButton(
                    onPressed: downloading
                        ? null
                        : () => Navigator.of(dialogContext).pop(),
                    child: const Text("Later"),
                  ),
                FilledButton(
                  onPressed: downloading ? null : startDownload,
                  child: Text(downloading ? "Downloading..." : "Update Now"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static Future<File?> _downloadApk(AppUpdateInfo latest) async {
    try {
      final client = http.Client();
      final request = http.Request("GET", Uri.parse(latest.downloadUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final directory = await getTemporaryDirectory();
      final file = File(
        "${directory.path}/fleet-driver-update-${latest.versionCode}.apk",
      );
      final sink = file.openWrite();
      await response.stream.pipe(sink);
      await sink.close();
      client.close();
      return file;
    } catch (_) {
      return null;
    }
  }
}

class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({
    super.key,
    required this.child,
  });

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_checked) return;
    _checked = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppUpdateService.checkAndPrompt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
