import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color _bg(String s) {
    switch (s.toLowerCase()) {
      case "approved":
        return const Color(0xFFDFF7E6);
      case "rejected":
        return const Color(0xFFFFE3E3);
      case "pending":
        return const Color(0xFFFFF3D6);
      case "no plan":
        return const Color(0xFFEFEFEF);
      default:
        return const Color(0xFFEFEFEF);
    }
  }

  Color _fg(String s) {
    switch (s.toLowerCase()) {
      case "approved":
        return const Color(0xFF1B7F3A);
      case "rejected":
        return const Color(0xFFB00020);
      case "pending":
        return const Color(0xFF9A6B00);
      case "no plan":
        return const Color(0xFF555555);
      default:
        return const Color(0xFF555555);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(status),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _fg(status),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}
