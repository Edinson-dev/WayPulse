import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../../core/constants/mapbox_constants.dart';
import 'package:waypulse_app/features/navigation/providers/navigation_provider.dart';
import '../widgets/turn_instruction_banner.dart';
import '../widgets/eta_bottom_bar.dart';
import 'package:waypulse_app/features/map/presentation/widgets/speed_limit_badge.dart';
import '../../../incidents/presentation/widgets/incident_fab_button.dart';
import '../../../incidents/presentation/widgets/report_incident_modal.dart';
import '../widgets/lane_guidance_widget.dart';
import '../widgets/trip_summary_dialog.dart';

import 'dart:async';
import '../../../../core/services/tts_voice_service.dart';
import '../widgets/route_progress_bar_widget.dart';

import '../../../incidents/providers/medellin_closures_provider.dart';

class NavigationModeScreen extends ConsumerStatefulWidget {
  const NavigationModeScreen({super.key});

  @override
  ConsumerState<NavigationModeScreen> createState() => _NavigationModeScreenState();
}

class _NavigationModeScreenState extends ConsumerState<NavigationModeScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  bool _isFollowingGps = true;
  Timer? _autoRecenterTimer;
  final TtsVoiceService _ttsService = TtsVoiceService();
  int _lastSpokenStepIndex = -1;
  DateTime? _lastSpeedingVoiceAlertTime;
  DateTime? _lastClosureVoiceAlertTime;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _autoRecenterTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onUserGesture() {
    if (_isFollowingGps) {
      setState(() {
        _isFollowingGps = false;
      });
    }
    _autoRecenterTimer?.cancel();
    _autoRecenterTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isFollowingGps = true;
        });
      }
    });
  }

  void _recenterGps(LatLng currentPos, double heading) {
    _autoRecenterTimer?.cancel();
    setState(() {
      _isFollowingGps = true;
    });
    _mapController.move(currentPos, 18.3);
    _mapController.rotate(-heading);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    final route = navState.selectedRoute;
    final currentStepIndex = navState.currentStepIndex;
    final currentStep = (route != null && currentStepIndex < route.steps.length)
        ? route.steps[currentStepIndex]
        : null;
    final nextStep = (route != null && (currentStepIndex + 1) < route.steps.length)
        ? route.steps[currentStepIndex + 1]
        : null;

    // Dictado por Voz Inteligente TTS de Instrucción de Giro
    if (currentStepIndex != _lastSpokenStepIndex && currentStep != null) {
      _lastSpokenStepIndex = currentStepIndex;
      _ttsService.speakInstruction('En ${currentStep.distanceMeters.toInt()} metros, ${currentStep.instruction}');
    }

    final currentSpeed = navState.currentLocation?.speedKmh ?? 0.0;
    final currentPos = navState.currentLocation?.position ??
        const LatLng(MapboxConstants.defaultLat, MapboxConstants.defaultLng);
    final rawHeading = navState.currentLocation?.heading ?? 0.0;
    final currentHeadingRad = rawHeading * (3.141592653589793 / 180.0);

    // Alerta de Voz por Exceso de Velocidad (> Límite permitido)
    final isSpeeding = currentSpeed > navState.currentSpeedLimit && currentSpeed > 10.0;
    if (isSpeeding) {
      final now = DateTime.now();
      if (_lastSpeedingVoiceAlertTime == null || now.difference(_lastSpeedingVoiceAlertTime!).inSeconds >= 12) {
        _lastSpeedingVoiceAlertTime = now;
        _ttsService.speakInstruction('Atención: estás excediendo el límite de velocidad de ${navState.currentSpeedLimit.toInt()} kilómetros por hora.');
      }
    }

    // Alerta por Voz de Cierres de Vía de Medellín Cercanos (< 400m)
    ref.listen(medellinClosuresProvider, (prev, next) {
      next.whenData((closures) {
        final now = DateTime.now();
        if (_lastClosureVoiceAlertTime != null &&
            now.difference(_lastClosureVoiceAlertTime!).inSeconds < 25) {
          return;
        }

        const distanceCalc = Distance();
        for (final closure in closures) {
          final pos = closure.point ?? (closure.polylines.isNotEmpty && closure.polylines.first.isNotEmpty ? closure.polylines.first.first : null);
          if (pos != null) {
            final distMeters = distanceCalc.as(LengthUnit.Meter, currentPos, pos);
            if (distMeters <= 400) {
              _lastClosureVoiceAlertTime = now;
              _ttsService.speakInstruction(
                'Alerta de vía: A ${distMeters.toInt()} metros hay un reporte de ${closure.title.isNotEmpty ? closure.title : "cierre vial en Medellín"}.',
              );
              break;
            }
          }
        }
      });
    });

    final topInset = MediaQuery.of(context).padding.top + 10;

    // Escuchar movimiento continuo del GPS para actualizar cámara en orientación Heading-Up (TomTom 3D)
    ref.listen(navigationProvider, (previous, next) {
      if (_isFollowingGps && next.currentLocation != null) {
        final prevLoc = previous?.currentLocation;
        final currLoc = next.currentLocation!;

        if (prevLoc == null ||
            prevLoc.position != currLoc.position ||
            (prevLoc.heading - currLoc.heading).abs() > 1.0) {
          // Zoom Adaptativo Inmersivo según velocidad
          double adaptiveZoom = 18.3;
          final spd = currLoc.speedKmh;
          if (spd > 65.0) {
            adaptiveZoom = 17.3; // Carretera rápida: ampliar visión
          } else if (spd < 20.0) {
            adaptiveZoom = 18.5; // Detención / Giros: visión ultra-cercana
          }
          _mapController.move(currLoc.position, adaptiveZoom);
          _mapController.rotate(-(currLoc.heading));
        }
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // Visor de Navegación 3D en Perspectiva TomTom GO (Zoom Inmersivo 18.3 Heading-Up)
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentPos,
                initialZoom: 18.3,
                maxZoom: 19.0,
                minZoom: 3.0,
                initialRotation: -rawHeading,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onUserGesture();
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.waypulse.waypulse_app',
                  tileProvider: CancellableNetworkTileProvider(),
                  maxZoom: 19,
                  maxNativeZoom: 18,
                  keepBuffer: 2,
                  panBuffer: 1,
                  tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                ),
                if (route != null)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      final pulseVal = _pulseAnimation.value;
                      return PolylineLayer(
                        polylines: [
                          // Capa 1: Glow azul suave Waze
                          Polyline(
                            points: route.polylinePoints,
                            color: const Color(0xFF1B4FD8).withValues(alpha: 0.20 + (pulseVal * 0.15)),
                            strokeWidth: 20.0 + (pulseVal * 3.0),
                          ),
                          // Capa 2: Borde blanco para contraste con el mapa
                          Polyline(
                            points: route.polylinePoints,
                            color: Colors.white,
                            strokeWidth: 13.0,
                          ),
                          // Capa 3: Línea principal azul Waze
                          Polyline(
                            points: route.polylinePoints,
                            color: const Color(0xFF1B9CF4),
                            strokeWidth: 10.0,
                          ),
                        ],
                      );
                    },
                  ),
                MarkerLayer(
                  markers: [
                    // Marcador Chevron Azul Waze en Navegación
                    Marker(
                      point: currentPos,
                      width: 70,
                      height: 70,
                      child: Transform.rotate(
                        angle: _isFollowingGps ? 0.0 : currentHeadingRad,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Halo difuso azul
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B9CF4).withValues(
                                  alpha: currentSpeed > navState.currentSpeedLimit ? 0.0 : 0.20,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Halo rojo si excede velocidad
                            if (currentSpeed > navState.currentSpeedLimit)
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30).withValues(alpha: 0.22),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            // Flecha Navegación 3D Estilo Waze
                            Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.003) // Perspectiva 3D
                                ..rotateX(0.45), // Inclinación 3D hacia adelante
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Sombra proyectada en el suelo (Efecto 3D elevación)
                                  Positioned(
                                    top: 6,
                                    child: Transform.scale(
                                      scaleY: 0.6,
                                      child: Icon(
                                        Icons.navigation_rounded,
                                        color: Colors.black.withValues(alpha: 0.35),
                                        size: 52,
                                      ),
                                    ),
                                  ),
                                  // Borde exterior blanco deslumbrante
                                  Icon(
                                    Icons.navigation_rounded,
                                    color: Colors.white,
                                    size: 54,
                                    shadows: [
                                      Shadow(
                                        color: (currentSpeed > navState.currentSpeedLimit
                                            ? const Color(0xFFFF3B30)
                                            : const Color(0xFF1B9CF4))
                                          .withValues(alpha: 0.6),
                                        blurRadius: 15,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  // Cuerpo principal 3D con Gradiente Azul Neón / Rojo exceso
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: currentSpeed > navState.currentSpeedLimit
                                          ? [const Color(0xFFFF6B6B), const Color(0xFFCC0000)]
                                          : [const Color(0xFF55C7FF), const Color(0xFF0066FF)],
                                    ).createShader(bounds),
                                    child: const Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  ),
                                  // Brillo superior 3D (Highlight)
                                  Positioned(
                                    top: 10,
                                    child: Icon(
                                      Icons.navigation_rounded,
                                      color: Colors.white.withValues(alpha: 0.40),
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Marcador de Destino Final Iluminado Neón
                    if (navState.destination != null)
                      Marker(
                        point: navState.destination!,
                        width: 52,
                        height: 52,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2E55),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF2E55).withValues(alpha: 0.6),
                                blurRadius: 18,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Lado Derecho: Barra Vertical de Progreso de Ruta (Estímulo Tráfico y Retenes)
          if (route != null)
            Positioned(
              top: topInset + 160,
              right: 16,
              child: RouteProgressBarWidget(
                route: route,
                currentStepIndex: navState.currentStepIndex,
                currentSpeedKmh: currentSpeed,
              ),
            ),

          // Banner Superior TomTom: Maniobra Actual y Sub-Banner "Luego en..."
          Positioned(
            top: topInset,
            left: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TurnInstructionBanner(
                  currentStep: currentStep,
                  nextStep: nextStep,
                ),
                const SizedBox(height: 6),
                LaneGuidanceWidget(
                  totalLanes: 4,
                  activeLaneIndex: 1,
                  nextManeuverText: currentStep?.instruction ?? 'Mantén el carril central',
                ),
              ],
            ),
          ),

          // Lado Izquierdo: Velocímetro Estilo TomTom
          Positioned(
            top: topInset + (nextStep != null ? 210 : 170),
            left: 12,
            child: SpeedLimitBadge(
              currentSpeedKmh: currentSpeed,
              speedLimitKmh: navState.currentSpeedLimit,
            ),
          ),

          // Lado Derecho: Botón Flotante "Centrar GPS" — blanco estilo Waze
          Positioned(
            bottom: 180,
            right: 16,
            child: GestureDetector(
              onTap: () => _recenterGps(currentPos, rawHeading),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isFollowingGps ? const Color(0xFF1B4FD8) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _isFollowingGps ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                  color: _isFollowingGps ? Colors.white : const Color(0xFF1B4FD8),
                  size: 24,
                ),
              ),
            ),
          ),

          // Lado Derecho: Reporte de Alertas en Ruta
          Positioned(
            bottom: 110,
            right: 16,
            child: IncidentFabButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => ReportIncidentModal(
                    onReport: (type, desc) {
                      navNotifier.reportIncident(type, desc);
                    },
                  ),
                );
              },
            ),
          ),

          // Barra Inferior: ETA, Tiempos, Distancia y Finalizar Navegación (TomTom Clean White Card)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ETABottomBar(
              durationSeconds: route?.durationSeconds ?? 0.0,
              distanceMeters: route?.distanceMeters ?? 0.0,
              destinationName: navState.destinationName,
              onStopNavigation: () {
                final distKm = (route?.distanceMeters ?? 0) / 1000.0;
                final durationMin = ((route?.durationSeconds ?? 0) / 60.0).round();
                final destName = navState.destinationName;

                navNotifier.stopNavigation();

                showDialog(
                  context: context,
                  builder: (ctx) => TripSummaryDialog(
                    destinationName: destName,
                    distanceKm: distKm,
                    durationMinutes: durationMin,
                    onClose: () => Navigator.pop(ctx),
                  ),
                );
              },
            ),
          ),
          if (isSpeeding)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.55),
                      width: 5,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
