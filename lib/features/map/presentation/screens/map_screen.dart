import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../../core/constants/mapbox_constants.dart';
import '../../../../core/constants/colombia_tolls_database.dart';
import '../../../../core/constants/speed_camera_database.dart';
import '../../../../core/constants/colombia_gas_stations_database.dart';
import '../../../../core/services/speed_camera_api_service.dart';
import '../../../navigation/providers/navigation_provider.dart';
import '../../../navigation/presentation/screens/navigation_mode_screen.dart';
import '../../../navigation/presentation/widgets/driver_earnings_sheet.dart';
import '../widgets/speed_limit_badge.dart';
import '../widgets/map_controls.dart';
import '../widgets/search_bar_overlay.dart';
import '../../../incidents/presentation/widgets/incident_fab_button.dart';
import '../../../incidents/presentation/widgets/report_incident_modal.dart';
import '../../../incidents/models/incident_model.dart';
import '../../../eco_route/presentation/widgets/route_selector_sheet.dart';
import '../../../../core/services/caravan_service.dart';
import '../../../caravan/presentation/widgets/caravan_modal.dart';
import '../../../incidents/presentation/widgets/sos_emergency_modal.dart';
import '../widgets/weather_badge_widget.dart';
import '../widgets/map_style_selector_sheet.dart';
import '../../../incidents/presentation/widgets/quick_report_bar.dart';
import '../../../incidents/models/medellin_closure_model.dart';
import '../../../incidents/providers/medellin_closures_provider.dart';
import '../../../navigation/presentation/widgets/pico_placa_badge.dart';
import '../../../navigation/presentation/widgets/pico_placa_config_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  final SpeedCameraApiService _cameraApiService = SpeedCameraApiService();
  final CaravanService _caravanService = CaravanService();

  List<SpeedCameraItem> _liveSpeedCameras = SpeedCameraDatabase.cameras;
  List<CaravanMember> _caravanMembers = [];

  bool _is3DMode = true;
  int _styleIndex = 0;
  bool _hasCenteredInitialPos = false;
  bool _isFollowingGps = true;
  bool _isSearchingDropdownOpen = false;
  bool _showTrafficFlow = true;

  final List<String> _tileStyles = [
    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
  ];

  String get _currentTileStyle {
    final hour = DateTime.now().hour;
    final isNight = hour >= 18 || hour < 6;
    if (_styleIndex == 0 && isNight) {
      return 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    }
    return _tileStyles[_styleIndex];
  }

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

    _loadLiveSpeedCameras();
    _caravanService.membersStream.listen((members) {
      if (mounted) {
        setState(() {
          _caravanMembers = members;
        });
      }
    });
    _caravanService.announcementsStream.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📣 Aviso de Caravana: $msg'),
            backgroundColor: const Color(0xFF8B5CF6),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _loadLiveSpeedCameras() async {
    final fetched = await _cameraApiService.fetchLiveSpeedCameras();
    if (mounted && fetched.isNotEmpty) {
      setState(() {
        _liveSpeedCameras = fetched;
      });
    }
  }

  Timer? _autoRecenterTimer;

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

  @override
  void dispose() {
    _autoRecenterTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _fitRouteBounds(LatLng origin, LatLng dest, List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints([origin, dest, ...points]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 140),
          maxZoom: 15.0,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    final isMedellinClosuresVisible = ref.watch(medellinClosuresVisibilityProvider);
    final medellinClosuresAsync = ref.watch(medellinClosuresProvider);
    final medellinClosures = isMedellinClosuresVisible
        ? (medellinClosuresAsync.valueOrNull ?? [])
        : <MedellinClosure>[];

    // Escuchar cambios en la ruta o ubicación para auto-centrar o encuadrar vista previa de ruta
    ref.listen(navigationProvider, (previous, next) {
      if (next.currentLocation != null) {
        if (!_hasCenteredInitialPos) {
          _hasCenteredInitialPos = true;
          _mapController.move(next.currentLocation!.position, 16.5);
        } else if (_isFollowingGps && previous?.currentLocation?.position != next.currentLocation?.position) {
          // Seguir dinámicamente al usuario mientras camina o conduce por la ruta
          _mapController.move(next.currentLocation!.position, _mapController.camera.zoom);
        }
        _caravanService.broadcastPosition(
          next.currentLocation!.position,
          next.currentLocation!.speedKmh,
        );
      }

      final isNewRouteSelected = next.selectedRoute != null &&
          next.destination != null &&
          (previous?.selectedRoute == null ||
              previous?.destination != next.destination ||
              previous?.selectedRoute?.id != next.selectedRoute?.id);

      if (isNewRouteSelected) {
        _fitRouteBounds(
          next.currentLocation?.position ?? const LatLng(MapboxConstants.defaultLat, MapboxConstants.defaultLng),
          next.destination!,
          next.selectedRoute!.polylinePoints,
        );
      }
    });

    if (navState.isNavigating) {
      return const NavigationModeScreen();
    }

    final currentPos = navState.currentLocation?.position ??
        const LatLng(MapboxConstants.defaultLat, MapboxConstants.defaultLng);
    final currentSpeed = navState.currentLocation?.speedKmh ?? 0.0;
    final currentHeading = (navState.currentLocation?.heading ?? 0.0) * (3.141592653589793 / 180.0);

    final topInset = MediaQuery.of(context).padding.top + 10;
    final cameraBounds = _hasCenteredInitialPos ? _mapController.camera.visibleBounds : null;
    bool isVisibleOnScreen(LatLng p) => cameraBounds == null || cameraBounds.contains(p);

    // Extraer puntos de alerta de tráfico pesado o accidentes para dibujar línea roja (Optimizado O(1) BBox)
    final List<Polyline> trafficLines = [];
    if (navState.selectedRoute != null) {
      final trafficIncidents = navState.activeIncidents.where(
        (inc) => inc.type == IncidentType.trafficJam || inc.type == IncidentType.crash,
      );
      if (trafficIncidents.isNotEmpty) {
        final routePts = navState.selectedRoute!.polylinePoints;
        for (final inc in trafficIncidents) {
          final incLat = inc.position.latitude;
          final incLng = inc.position.longitude;
          for (int i = 0; i < routePts.length - 1; i += 2) {
            final pt = routePts[i];
            // Pre-filtro delta lat/lng ultra-rápido para evitar trigonometría pesada
            if ((incLat - pt.latitude).abs() < 0.002 && (incLng - pt.longitude).abs() < 0.002) {
              final dist = const Distance().as(LengthUnit.Meter, inc.position, pt);
              if (dist < 150) {
                final startIdx = (i - 4).clamp(0, routePts.length - 1);
                final endIdx = (i + 4).clamp(0, routePts.length - 1);
                trafficLines.add(
                  Polyline(
                    points: routePts.sublist(startIdx, endIdx + 1),
                    color: const Color(0xFFFF2E55),
                    strokeWidth: 9.0,
                  ),
                );
                break;
              }
            }
          }
        }
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          // Capa de Mapa Mosaicos Waze Light Ultra-Rápidos
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: currentPos,
                initialZoom: 16.5,
                maxZoom: 18.5,
                minZoom: 3.0,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    _onUserGesture();
                  }
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey('waze_permanent_tile_layer_$_styleIndex'),
                  urlTemplate: _currentTileStyle,
                  fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.waypulse.waypulse_app',
                  tileProvider: CancellableNetworkTileProvider(),
                  maxZoom: 19,
                  maxNativeZoom: 18,
                  keepBuffer: 2,
                  panBuffer: 1,
                  tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
                ),
                if (isMedellinClosuresVisible && medellinClosures.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      for (final closure in medellinClosures)
                        for (final line in closure.polylines)
                          Polyline(
                            points: line,
                            color: closure.color,
                            strokeWidth: closure.category == MedellinClosureCategory.detour ? 4.5 : 6.5,
                          ),
                    ],
                  ),
                if (navState.selectedRoute != null) ...[
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) {
                      final pulseVal = _pulseAnimation.value;
                      return PolylineLayer(
                        polylines: [
                          // Capa 1: Sombra azul exterior Waze (glow suave)
                          Polyline(
                            points: navState.selectedRoute!.polylinePoints,
                            color: const Color(0xFF1B4FD8).withValues(alpha: 0.18 + (pulseVal * 0.18)),
                            strokeWidth: 18.0 + (pulseVal * 3.0),
                          ),
                          // Capa 2: Borde blanco para contraste con el mapa
                          Polyline(
                            points: navState.selectedRoute!.polylinePoints,
                            color: Colors.white,
                            strokeWidth: 11.0,
                          ),
                          // Capa 3: Línea principal azul Waze
                          Polyline(
                            points: navState.selectedRoute!.polylinePoints,
                            color: const Color(0xFF1B9CF4),
                            strokeWidth: 8.0,
                          ),
                          // Trazado de segmento rojo para tráfico pesado / accidentes
                          ...trafficLines,
                        ],
                      );
                    },
                  ),
                ],
                MarkerLayer(
                  markers: [
                    // Marcador GPS estilo Chevron Naranja Waze con Rotación por Brújula
                    Marker(
                      point: currentPos,
                      width: 60,
                      height: 60,
                      child: Transform.rotate(
                        angle: currentHeading,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Sombra circular difusa
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                            ),
                            // Chevron naranja sólido Waze
                            const Icon(
                              Icons.navigation_rounded,
                              color: Color(0xFFFF6B00),
                              size: 42,
                              shadows: [
                                Shadow(
                                  color: Color(0x88FF6B00),
                                  blurRadius: 16,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Marcadores de Cierres de Movilidad de Medellín (Alcaldía) 🚧
                    ...medellinClosures.where((c) {
                      final pos = c.point ?? (c.polylines.isNotEmpty && c.polylines.first.isNotEmpty ? c.polylines.first.first : null);
                      return pos != null && isVisibleOnScreen(pos);
                    }).map((closure) {
                      final pos = closure.point ?? closure.polylines.first.first;
                      return Marker(
                        point: pos,
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🏛️ Alcaldía de Medellín - ${closure.categoryLabel}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent),
                                    ),
                                    const SizedBox(height: 2),
                                    Text('📍 ${closure.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('ℹ️ ${closure.description}', style: const TextStyle(fontSize: 12)),
                                  ],
                                ),
                                backgroundColor: const Color(0xFF1E293B),
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: closure.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: closure.color.withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Icon(
                              closure.icon,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      );
                    }),
                    // Marcadores de Incidentes en Tiempo Real (Filtrado Espacial 60 FPS)
                    ...navState.activeIncidents.where((inc) => isVisibleOnScreen(inc.position)).map(
                      (inc) => Marker(
                        point: inc.position,
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⚠️ ${inc.title}: ${inc.description}'),
                                backgroundColor: inc.color,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: inc.color, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              inc.icon,
                              color: inc.color,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Marcadores de Peajes en Colombia (Filtrado Espacial 60 FPS)
                    ...ColombiaTollsDatabase.tolls.where((toll) => isVisibleOnScreen(toll.position)).map(
                      (toll) => Marker(
                        point: toll.position,
                        width: 38,
                        height: 38,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🛣️ ${toll.name} (${toll.locationName}) - Tarifa: \$${toll.priceCop} COP'),
                                backgroundColor: const Color(0xFFF59E0B),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF59E0B), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.toll_rounded, color: Color(0xFFF59E0B), size: 20),
                          ),
                        ),
                      ),
                    ),
                    // Marcadores de Cámaras de Fotomultas en Medellín & Colombia (Filtrado Espacial 60 FPS)
                    ..._liveSpeedCameras.where((cam) => isVisibleOnScreen(cam.position)).map(
                      (cam) => Marker(
                        point: cam.position,
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('📷 Cámara Fotomulta (${cam.locationName}) - Máx ${cam.maxSpeedKmh} km/h'),
                                backgroundColor: const Color(0xFFFF3B30),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFFF3B30), width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF3B30), size: 18),
                          ),
                        ),
                      ),
                    ),
                    // Marcadores de Miembros de Caravana en Vivo 👥 (Filtrado Espacial 60 FPS)
                    ..._caravanMembers
                        .where((m) => m.id != _caravanService.currentMemberId && isVisibleOnScreen(m.position))
                        .map(
                      (member) => Marker(
                        point: member.position,
                        width: 90,
                        height: 60,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('👥 ${member.nickname} (${member.vehicleType == "bike" ? "Moto" : "Carro"}) • ${member.speedKmh.toInt()} km/h'),
                                backgroundColor: const Color(0xFF8B5CF6),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF8B5CF6)),
                                ),
                                child: Text(
                                  member.nickname,
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  member.vehicleType == 'bike' ? Icons.two_wheeler_rounded : Icons.directions_car_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Marcadores de Gasolineras (Terpel/Texaco) y Cargadores Eléctricos EPM (Filtrado Espacial 60 FPS)
                    ...ColombiaGasStationsDatabase.stations.where((st) => isVisibleOnScreen(st.position)).map(
                      (st) => Marker(
                        point: st.position,
                        width: 34,
                        height: 34,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(st.isElectricCharging
                                    ? '⚡ ${st.name} - ${st.address}'
                                    : '⛽ ${st.name} (${st.brand}) - ${st.address}'),
                                backgroundColor: st.isElectricCharging
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF2563EB),
                              ),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: st.isElectricCharging
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              st.isElectricCharging ? Icons.ev_station_rounded : Icons.local_gas_station_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Overlay Superior: Barra de Búsqueda O Encabezado de Vista Previa estilo Waze (blanco)
          if (navState.availableRoutes.isNotEmpty)
            Positioned(
              top: topInset,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A1A2E)),
                      onPressed: () => navNotifier.stopNavigation(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tu ubicación',
                            style: TextStyle(color: Color(0xFF999EB5), fontSize: 12),
                          ),
                          Text(
                            '➔ ${navState.destinationName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A1A2E),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              top: topInset,
              left: 12,
              right: 12,
              child: SearchBarOverlay(
                onPlaceSelected: (pos, name) {
                  FocusScope.of(context).unfocus();
                  navNotifier.calculateRoutesTo(pos, name);
                },
                onSearchingStateChanged: (isSearching) {
                  setState(() => _isSearchingDropdownOpen = isSearching);
                },
              ),
            ),

          // Overlay Superior: Badge interactivo de Pico y Placa (Ubicado justo bajo la barra de búsqueda)
          if (!_isSearchingDropdownOpen && navState.availableRoutes.isEmpty && navState.picoPlacaResult != null)
            Positioned(
              top: topInset + 56,
              left: 12,
              right: 12,
              child: PicoPlacaBadge(
                result: navState.picoPlacaResult!,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => PicoPlacaConfigSheet(
                      initialDigit: navState.vehiclePlateDigit,
                      initialCity: navState.selectedCity,
                      onSave: (digit, city) {
                        navNotifier.setVehiclePlateDigit(digit);
                        navNotifier.setSelectedCity(city);
                      },
                    ),
                  );
                },
              ),
            ),

          // Overlay Superior Izquierdo: Badge de Clima y Estado de Vía
          if (!_isSearchingDropdownOpen && navState.availableRoutes.isEmpty)
            Positioned(
              top: topInset + 118,
              left: 12,
              child: const WeatherBadgeWidget(
                condition: '⛅ Sol Parcial',
                tempCelsius: 24,
                statusText: 'Vía Seca • Óptima',
              ),
            ),

          // Overlay Izquierdo: Velocímetro
          if (!_isSearchingDropdownOpen && navState.availableRoutes.isEmpty)
            Positioned(
              top: topInset + 158,
              left: 12,
              child: SpeedLimitBadge(
                currentSpeedKmh: currentSpeed,
                speedLimitKmh: navState.currentSpeedLimit,
              ),
            ),

          // Overlay Derecho: Controles del Mapa 2D/3D (Alineado con el panel superior derecho)
          if (!_isSearchingDropdownOpen)
            Positioned(
              top: topInset + (navState.availableRoutes.isNotEmpty ? 70 : 108),
              right: 12,
              child: MapControlsWidget(
                is3DMode: _is3DMode,
                onToggle3D: () {
                  setState(() => _is3DMode = !_is3DMode);
                  _mapController.rotate(_is3DMode ? 0.0 : 35.0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_is3DMode ? 'Modo 2D Norte Arriba Activo' : 'Modo 3D Perspectiva Activo'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onRecenter: () {
                  setState(() {
                    _isFollowingGps = true;
                    _hasCenteredInitialPos = true;
                  });
                  _mapController.move(currentPos, 17.5);
                  _mapController.rotate(0.0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('🎯 Recentrado y rastreo GPS 3D activado'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                onToggleTraffic: () {
                  setState(() => _showTrafficFlow = !_showTrafficFlow);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_showTrafficFlow ? 'Capa de Tráfico en Tiempo Real Activada' : 'Capa de Tráfico Oculta'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                isTrafficActive: _showTrafficFlow,
                onToggleLayers: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => MapStyleSelectorSheet(
                      currentStyleIndex: _styleIndex,
                      onSelectStyle: (idx) {
                        setState(() => _styleIndex = idx);
                      },
                    ),
                  );
                },
              ),
            ),

          // Overlay Inferior 1: Tira de Reportes Rápidos en 1-Tap (Flotante a 74px sin chocar con botones)
          if (navState.availableRoutes.isEmpty && !_isSearchingDropdownOpen)
            Positioned(
              bottom: 74,
              left: 12,
              right: 12,
              child: QuickReportBar(
                onReport: (type, desc) {
                  navNotifier.reportIncident(type, desc);
                },
              ),
            ),

          // Overlay Inferior 2: Fila Principal de Botones de Acción (Alerta, Caravana, Ganancias, Leaderboard, SOS)
          if (navState.availableRoutes.isEmpty && !_isSearchingDropdownOpen)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IncidentFabButton(
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
                      const SizedBox(width: 10),
                      // Botón Modo Caravana / Rodada en Grupo 👥
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => CaravanModal(
                              caravanService: _caravanService,
                              currentPos: currentPos,
                              onStateChanged: () => setState(() {}),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _caravanService.currentGroupCode != null ? Icons.groups_rounded : Icons.group_add_rounded,
                            color: const Color(0xFF8B5CF6),
                            size: 22,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Botón Calculadora Conductores (Uber/InDrive/Combustible)
                      GestureDetector(
                        onTap: () {
                          final selected = navState.selectedRoute;
                          final dist = selected != null ? (selected.distanceMeters / 1000.0) : 12.5;
                          final dur = selected != null ? (selected.durationSeconds / 60.0) : 25.0;
                          final tolls = ColombiaTollsDatabase.calculateTotalTolls(
                            currentPos,
                            navState.destination ?? currentPos,
                          );
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => DriverEarningsSheet(
                              distanceKm: dist,
                              durationMinutes: dur,
                              tollsCop: tolls,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.attach_money_rounded, color: Color(0xFF10B981), size: 22),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Floating SOS Emergency Button
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => SosEmergencyModal(currentPos: currentPos),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF3B30),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 4),
                              Text(
                                'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

          // Overlay Inferior Deslizable: Selector de Rutas Eco vs Rápidas (Compacto estilo Imagen 1)
          if (navState.availableRoutes.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: RouteSelectorSheet(
                routes: navState.availableRoutes,
                selectedRoute: navState.selectedRoute,
                onSelect: (route) => navNotifier.selectRoute(route),
                onStartNavigation: () => navNotifier.startNavigation(),
                onCancel: () => navNotifier.cancelRoute(),
                picoPlacaResult: navState.picoPlacaResult,
              ),
            ),
        ],
      ),
    );
  }
}

/// CustomPainter para la renderización de la red del mapa, cuadrículas de avenidas y trazado de rutas
class MapGridPainter extends CustomPainter {
  final LatLng userPosition;
  final List routes;
  final dynamic selectedRoute;
  final List incidents;
  final bool is3D;

  MapGridPainter({
    required this.userPosition,
    required this.routes,
    required this.selectedRoute,
    required this.incidents,
    required this.is3D,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Fondo oscuro con rejilla estética de ciudad
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.5)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Dibujo de avenidas principales
    final roadPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 14.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), roadPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), roadPaint);

    // Si hay una ruta seleccionada, dibujamos la línea brillante de dirección Mapbox Neon
    if (selectedRoute != null) {
      final routePaint = Paint()
        ..color = const Color(0xFF00C8FF)
        ..strokeWidth = 8.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.quadraticBezierTo(
        center.dx + 80,
        center.dy - 120,
        center.dx + 120,
        center.dy - 250,
      );

      canvas.drawPath(path, routePaint);
    }

    // Dibujo del marcador del auto del usuario en el centro (Icono estilo Waze)
    final carPaint = Paint()..color = const Color(0xFF00C8FF);
    final glowPaint = Paint()
      ..color = const Color(0xFF00C8FF).withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, 22, glowPaint);
    canvas.drawCircle(center, 12, carPaint);
    canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
