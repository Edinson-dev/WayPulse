import 'package:flutter/material.dart';
import '../../../../core/services/mapbox_directions_service.dart';
import '../../../../core/utils/distance_formatter.dart';

import '../../../../core/services/pico_placa_service.dart';
import '../../../../features/navigation/presentation/widgets/pico_placa_badge.dart';

class RouteSelectorSheet extends StatelessWidget {
  final List<MapboxRoute> routes;
  final MapboxRoute? selectedRoute;
  final Function(MapboxRoute route) onSelect;
  final VoidCallback onStartNavigation;
  final VoidCallback? onCancel;
  final PicoPlacaResult? picoPlacaResult;
  final VoidCallback? onConfigurePicoPlaca;

  const RouteSelectorSheet({
    super.key,
    required this.routes,
    required this.selectedRoute,
    required this.onSelect,
    required this.onStartNavigation,
    this.onCancel,
    this.picoPlacaResult,
    this.onConfigurePicoPlaca,
  });

  @override
  Widget build(BuildContext context) {
    final activeRoute = selectedRoute ?? (routes.isNotEmpty ? routes.first : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Header con título y botón de cierre X
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vista Previa de Ruta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (onCancel != null)
                InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (picoPlacaResult != null)
            PicoPlacaBadge(
              result: picoPlacaResult!,
              onTap: onConfigurePicoPlaca,
            ),

          // Lista Horizontal / Compacta de Opciones de Ruta
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final r = routes[index];
                final isSelected = activeRoute?.id == r.id;

                return GestureDetector(
                  onTap: () => onSelect(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 170,
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF00C8FF).withValues(alpha: 0.18)
                          : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF00C8FF) : const Color(0xFF334155),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              DistanceFormatter.formatDuration(r.durationSeconds),
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00C8FF) : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                              ),
                            ),
                            const Spacer(),
                            if (r.isEcoFriendly)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ECO',
                                  style: TextStyle(
                                    color: Color(0xFF00E676),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DistanceFormatter.formatDistance(r.distanceMeters)} • ETA ${DistanceFormatter.calculateETA(r.durationSeconds)}',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Botones de Acción: Cancelar e Ir Ahora
          Row(
            children: [
              if (onCancel != null)
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              if (onCancel != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onStartNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C8FF),
                      elevation: 4,
                      shadowColor: const Color(0xFF00C8FF).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: const Text(
                      'Ir ahora',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
