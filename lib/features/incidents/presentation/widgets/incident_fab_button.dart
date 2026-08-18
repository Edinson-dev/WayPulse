import 'package:flutter/material.dart';

class IncidentFabButton extends StatelessWidget {
  final VoidCallback onPressed;

  const IncidentFabButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF2E55)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.report_problem_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'ALERTA',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
