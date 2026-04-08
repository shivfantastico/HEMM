import 'package:flutter/material.dart';

class AdminBranding {
  static const Color background = Color(0xFFF4F5F8);
  static const Color primaryText = Color(0xFF1E2432);
  static const Color secondaryText = Color(0xFF616C83);
  static const Color cardBorder = Color(0xFFE9ECF3);

  static PreferredSizeWidget appBar({
    required String title,
    List<Widget>? actions,
  }) {
    return AppBar(
      backgroundColor: Colors.transparent,
      foregroundColor: primaryText,
      iconTheme: const IconThemeData(color: primaryText),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryText,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: [
        ...?actions,
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: LogoBadge(),
        ),
      ],
    );
  }
}

class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Image.asset("assets/lloyds_logo.png"),
      ),
    );
  }
}
