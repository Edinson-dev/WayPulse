import 'package:flutter/material.dart';
import '../../models/incident_model.dart';

class QuickReportBar extends StatelessWidget {
  final Function(IncidentType type, String description) onReport;

  const QuickReportBar({
    super.key,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final quickItems = [
      {
        'type': IncidentType.speedCamera,
        'label': 'Fotomulta',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFFFF3B30),
      },
      {
        'type': IncidentType.transitAgent,
        'label': 'Retén',
        'icon': Icons.local_police_rounded,
        'color': const Color(0xFF1B4FD8),
      },
      {
        'type': IncidentType.pothole,
        'label': 'Hueco',
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFFF9500),
      },
      {
        'type': IncidentType.trafficJam,
        'label': 'Tráfico',
        'icon': Icons.traffic_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'type': IncidentType.flooding,
        'label': 'Lluvia',
        'icon': Icons.water_drop_rounded,
        'color': const Color(0xFF06B6D4),
      },
    ];

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: quickItems.map((item) {
            final type = item['type'] as IncidentType;
            final label = item['label'] as String;
            final icon = item['icon'] as IconData;
            final color = item['color'] as Color;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                onTap: () {
                  onReport(type, '$label reportado en tiempo real');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('⚡ ¡Reporte de $label publicado!'),
                      backgroundColor: color,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
