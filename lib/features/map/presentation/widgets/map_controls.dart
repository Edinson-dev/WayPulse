import 'package:flutter/material.dart';

class MapControlsWidget extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onToggle3D;
  final bool is3DMode;
  final VoidCallback onToggleLayers;
  final VoidCallback? onToggleTraffic;
  final bool isTrafficActive;
  final VoidCallback? onConfigurePicoPlaca;

  const MapControlsWidget({
    super.key,
    required this.onRecenter,
    required this.onToggle3D,
    required this.is3DMode,
    required this.onToggleLayers,
    this.onToggleTraffic,
    this.isTrafficActive = true,
    this.onConfigurePicoPlaca,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildButton(
          icon: is3DMode ? Icons.view_in_ar_rounded : Icons.map_rounded,
          label: is3DMode ? '3D' : '2D',
          onPressed: onToggle3D,
          accentColor: is3DMode ? const Color(0xFF1B4FD8) : null,
        ),
        const SizedBox(height: 10),
        if (onToggleTraffic != null) ...[
          _buildButton(
            icon: Icons.traffic_rounded,
            onPressed: onToggleTraffic!,
            accentColor: isTrafficActive ? const Color(0xFFFF6B00) : null,
          ),
          const SizedBox(height: 10),
        ],
        _buildButton(
          icon: Icons.layers_rounded,
          onPressed: onToggleLayers,
        ),
        const SizedBox(height: 10),
        if (onConfigurePicoPlaca != null) ...[
          _buildButton(
            icon: Icons.directions_car_rounded,
            onPressed: onConfigurePicoPlaca!,
            accentColor: const Color(0xFF10B981),
            iconColor: Colors.white,
          ),
          const SizedBox(height: 10),
        ],
        // Botón de recentrar — azul marino Waze cuando activo
        _buildButton(
          icon: Icons.my_location_rounded,
          onPressed: onRecenter,
          accentColor: const Color(0xFF1B4FD8),
          iconColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildButton({
    required IconData icon,
    String? label,
    required VoidCallback onPressed,
    Color? accentColor,
    Color? iconColor,
  }) {
    final bool hasAccent = accentColor != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasAccent ? accentColor : Colors.white,
            boxShadow: [
              BoxShadow(
                color: hasAccent
                    ? accentColor.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: label != null
                ? Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: iconColor ?? Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                    color: iconColor ?? (hasAccent ? Colors.white : const Color(0xFF333355)),
                    size: 22,
                  ),
          ),
        ),
      ),
    );
  }
}
