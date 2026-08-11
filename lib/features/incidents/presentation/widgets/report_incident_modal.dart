import 'package:flutter/material.dart';
import '../../models/incident_model.dart';

class ReportIncidentModal extends StatelessWidget {
  final Function(IncidentType type, String note) onReport;

  const ReportIncidentModal({super.key, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> options = [
      {'type': IncidentType.transitAgent, 'label': 'Tránsito', 'icon': Icons.shield_rounded, 'color': const Color(0xFF00E5FF)},
      {'type': IncidentType.police, 'label': 'Policía', 'icon': Icons.local_police_rounded, 'color': const Color(0xFF29B6F6)},
      {'type': IncidentType.speedCamera, 'label': 'Radar', 'icon': Icons.camera_alt_rounded, 'color': const Color(0xFFFFB300)},
      {'type': IncidentType.trafficJam, 'label': 'Tráfico', 'icon': Icons.traffic_rounded, 'color': const Color(0xFFFF6B00)},
      {'type': IncidentType.crash, 'label': 'Accidente', 'icon': Icons.car_crash_rounded, 'color': const Color(0xFFFF2E55)},
      {'type': IncidentType.pothole, 'label': 'Hueco', 'icon': Icons.broken_image_rounded, 'color': const Color(0xFFFF5722)},
      {'type': IncidentType.flooding, 'label': 'Inundación', 'icon': Icons.water_drop_rounded, 'color': const Color(0xFF00B0FF)},
      {'type': IncidentType.hazard, 'label': 'Peligro', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFFF9100)},
      {'type': IncidentType.construction, 'label': 'Obras', 'icon': Icons.engineering_rounded, 'color': const Color(0xFFAB47BC)},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '¿Qué ves en la vía?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ayuda a la comunidad WayPulse reportando eventos en la vía',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              return InkWell(
                onTap: () {
                  onReport(opt['type'] as IncidentType, '');
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: (opt['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: (opt['color'] as Color).withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(opt['icon'] as IconData, color: opt['color'] as Color, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        opt['label'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
