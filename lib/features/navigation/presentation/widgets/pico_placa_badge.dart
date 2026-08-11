import 'package:flutter/material.dart';
import '../../../../core/services/pico_placa_service.dart';

class PicoPlacaBadge extends StatelessWidget {
  final PicoPlacaResult result;
  final VoidCallback? onTap;

  const PicoPlacaBadge({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isRestricted = result.isRestricted;

    final badgeChild = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isRestricted ? const Color(0xFFFFF0F0) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRestricted
              ? const Color(0xFFFF3B30).withValues(alpha: 0.6)
              : const Color(0xFF10B981).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isRestricted ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
            color: isRestricted ? const Color(0xFFFF3B30) : const Color(0xFF10B981),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRestricted
                      ? '🚨 PICO Y PLACA EN ${result.cityName.toUpperCase()}'
                      : '🟢 LIBRE DE PICO Y PLACA EN ${result.cityName.toUpperCase()}',
                  style: TextStyle(
                    color: isRestricted ? const Color(0xFF990000) : const Color(0xFF065F46),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result.message,
                  style: const TextStyle(
                    color: Color(0xFF444466),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.edit_rounded,
              color: Color(0xFF8888AA),
              size: 16,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: badgeChild,
      );
    }

    return badgeChild;
  }
}
