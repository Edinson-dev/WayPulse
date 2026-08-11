import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/mapbox_directions_service.dart';
import '../../../core/services/tts_voice_service.dart';
import '../../incidents/models/incident_model.dart';

import '../../../core/services/pico_placa_service.dart';

import '../../../core/services/realtime_incident_service.dart';

enum TransportMode { car, moto, bike, walk, transit }

class NavigationState {
  final UserLocation? currentLocation;
  final LatLng? destination;
  final String destinationName;
  final List<MapboxRoute> availableRoutes;
  final MapboxRoute? selectedRoute;
  final bool isNavigating;
  final int currentStepIndex;
  final double currentSpeedLimit;
  final List<IncidentReport> activeIncidents;
  final int pulsePoints;
  final TransportMode selectedTransportMode;
  final int vehiclePlateDigit;
  final ColombianCity selectedCity;

  NavigationState({
    this.currentLocation,
    this.destination,
    this.destinationName = '',
    this.availableRoutes = const [],
    this.selectedRoute,
    this.isNavigating = false,
    this.currentStepIndex = 0,
    this.currentSpeedLimit = 80.0,
    this.activeIncidents = const [],
    this.pulsePoints = 140,
    this.selectedTransportMode = TransportMode.car,
    this.vehiclePlateDigit = 4,
    this.selectedCity = ColombianCity.medellin,
  });

  PicoPlacaResult? get picoPlacaResult {
    return PicoPlacaService().checkRestriction(
      plateLastDigit: vehiclePlateDigit,
      city: selectedCity,
    );
  }

  NavigationState copyWith({
    UserLocation? currentLocation,
    LatLng? destination,
    String? destinationName,
    List<MapboxRoute>? availableRoutes,
    MapboxRoute? selectedRoute,
    bool? isNavigating,
    int? currentStepIndex,
    double? currentSpeedLimit,
    List<IncidentReport>? activeIncidents,
    int? pulsePoints,
    TransportMode? selectedTransportMode,
    int? vehiclePlateDigit,
    ColombianCity? selectedCity,
    bool clearRoute = false,
  }) {
    if (clearRoute) {
      return NavigationState(
        currentLocation: currentLocation ?? this.currentLocation,
        destination: null,
        destinationName: '',
        availableRoutes: const [],
        selectedRoute: null,
        isNavigating: false,
        currentStepIndex: 0,
        currentSpeedLimit: currentSpeedLimit ?? this.currentSpeedLimit,
        activeIncidents: activeIncidents ?? this.activeIncidents,
        pulsePoints: pulsePoints ?? this.pulsePoints,
        selectedTransportMode: selectedTransportMode ?? this.selectedTransportMode,
        vehiclePlateDigit: vehiclePlateDigit ?? this.vehiclePlateDigit,
        selectedCity: selectedCity ?? this.selectedCity,
      );
    }
    return NavigationState(
      currentLocation: currentLocation ?? this.currentLocation,
      destination: destination ?? this.destination,
      destinationName: destinationName ?? this.destinationName,
      availableRoutes: availableRoutes ?? this.availableRoutes,
      selectedRoute: selectedRoute ?? this.selectedRoute,
      isNavigating: isNavigating ?? this.isNavigating,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      currentSpeedLimit: currentSpeedLimit ?? this.currentSpeedLimit,
      activeIncidents: activeIncidents ?? this.activeIncidents,
      pulsePoints: pulsePoints ?? this.pulsePoints,
      selectedTransportMode: selectedTransportMode ?? this.selectedTransportMode,
      vehiclePlateDigit: vehiclePlateDigit ?? this.vehiclePlateDigit,
      selectedCity: selectedCity ?? this.selectedCity,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  final MapboxDirectionsService _directionsService = MapboxDirectionsService();
  final LocationService _locationService = LocationService();
  final TtsVoiceService _ttsService = TtsVoiceService();
  final RealtimeIncidentService _realtimeIncidentService = RealtimeIncidentService();

  NavigationNotifier() : super(NavigationState()) {
    _initLocationListener();
    _initCloudIncidentsListener();
    _loadInitialMockIncidents();
    requestInitialLocation();
  }

  void _initCloudIncidentsListener() {
    _realtimeIncidentService.incidentsStream.listen((cloudIncidents) {
      state = state.copyWith(activeIncidents: cloudIncidents);
    });
  }

  Future<void> requestInitialLocation() async {
    final pos = await _locationService.getCurrentPosition();
    if (pos != null) {
      state = state.copyWith(
        currentLocation: UserLocation(
          position: LatLng(pos.latitude, pos.longitude),
          speedKmh: (pos.speed < 0 ? 0 : pos.speed) * 3.6,
          heading: pos.heading,
          altitude: pos.altitude,
        ),
      );
    }
  }

  void setTransportMode(TransportMode mode) {
    double speedLimit = 80.0;
    switch (mode) {
      case TransportMode.car:
        speedLimit = 80.0;
        break;
      case TransportMode.moto:
        speedLimit = 60.0;
        break;
      case TransportMode.bike:
        speedLimit = 30.0;
        break;
      case TransportMode.walk:
        speedLimit = 6.0;
        break;
      case TransportMode.transit:
        speedLimit = 40.0;
        break;
    }

    state = state.copyWith(
      selectedTransportMode: mode,
      currentSpeedLimit: speedLimit,
    );

    if (state.destination != null) {
      calculateRoutesTo(state.destination!, state.destinationName);
    }
  }

  void setVehiclePlateDigit(int digit) {
    state = state.copyWith(vehiclePlateDigit: digit.clamp(0, 9));
  }

  void setSelectedCity(ColombianCity city) {
    state = state.copyWith(selectedCity: city);
  }

  void _initLocationListener() {
    _locationService.getRealtimeLocationStream().listen((userLoc) {
      state = state.copyWith(currentLocation: userLoc);

      if (state.selectedRoute != null) {
        _updateTrimmedRoute(userLoc);
      }

      if (state.isNavigating && state.selectedRoute != null) {
        _checkStepProgress(userLoc);
      }
    });
  }

  bool _isRerouting = false;
  DateTime? _lastRerouteTime;

  void _updateTrimmedRoute(UserLocation userLoc) {
    final route = state.selectedRoute;
    if (route == null) return;
    final pts = route.polylinePoints;
    if (pts.length < 2) return;

    // Encontrar el punto de la polilínea más cercano a la ubicación actual del usuario
    int closestIdx = 0;
    double minDistance = double.infinity;
    const distance = Distance();

    for (int i = 0; i < pts.length; i++) {
      final d = distance.as(LengthUnit.Meter, userLoc.position, pts[i]);
      if (d < minDistance) {
        minDistance = d;
        closestIdx = i;
      }
    }

    // Detección de Desvío / Salida de la ruta (Off-Route > 40m): Auto-Rerouting
    if (minDistance > 40.0 && state.destination != null && !_isRerouting) {
      final now = DateTime.now();
      if (_lastRerouteTime == null || now.difference(_lastRerouteTime!).inSeconds >= 5) {
        _isRerouting = true;
        _lastRerouteTime = now;
        _ttsService.speakInstruction('Recalculando ruta...');
        calculateRoutesTo(state.destination!, state.destinationName).then((_) {
          _isRerouting = false;
        }).catchError((_) {
          _isRerouting = false;
        });
        return;
      }
    }

    // Si el usuario avanza por la ruta (dentro del margen de 35 metros), recortar los puntos ya recorridos
    if (minDistance <= 35.0 && closestIdx > 0 && closestIdx < pts.length - 1) {
      final remainingPts = [userLoc.position, ...pts.sublist(closestIdx)];
      final updatedRoute = route.copyWith(polylinePoints: remainingPts);
      state = state.copyWith(selectedRoute: updatedRoute);
    }
  }

  void _checkStepProgress(UserLocation userLoc) {
    final route = state.selectedRoute!;
    if (state.currentStepIndex < route.steps.length) {
      final currentStep = route.steps[state.currentStepIndex];
      final distToStep = const Distance().as(
        LengthUnit.Meter,
        userLoc.position,
        currentStep.location,
      );

      if (distToStep < 50) {
        _ttsService.speakInstruction(currentStep.instruction);
        if (state.currentStepIndex + 1 < route.steps.length) {
          state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
        }
      }
    }
  }

  Future<void> calculateRoutesTo(LatLng dest, String name) async {
    final currentPos = state.currentLocation?.position ??
        const LatLng(4.60971, -74.08175);

    String profileStr = 'driving';
    switch (state.selectedTransportMode) {
      case TransportMode.car:
        profileStr = 'driving';
        break;
      case TransportMode.moto:
        profileStr = 'driving';
        break;
      case TransportMode.bike:
        profileStr = 'cycling';
        break;
      case TransportMode.walk:
        profileStr = 'walking';
        break;
      case TransportMode.transit:
        profileStr = 'walking';
        break;
    }

    final routes = await _directionsService.fetchRoutes(
      origin: currentPos,
      destination: dest,
      profile: profileStr,
    );

    if (routes.isNotEmpty) {
      state = state.copyWith(
        destination: dest,
        destinationName: name,
        availableRoutes: routes,
        selectedRoute: routes.first,
      );
    }
  }

  void selectRoute(MapboxRoute route) {
    state = state.copyWith(selectedRoute: route);
  }

  void startNavigation() {
    if (state.selectedRoute != null) {
      state = state.copyWith(
        isNavigating: true,
        currentStepIndex: 0,
      );

      final firstStep = state.selectedRoute!.steps.firstOrNull;
      if (firstStep != null) {
        _ttsService.speakInstruction('Iniciando ruta hacia ${state.destinationName}. ${firstStep.instruction}');
      }
    }
  }

  void cancelRoute() {
    _ttsService.speakInstruction('Ruta cancelada.');
    state = state.copyWith(clearRoute: true);
  }

  void stopNavigation() {
    _ttsService.speakInstruction('Navegación finalizada.');
    state = state.copyWith(clearRoute: true);
  }

  void reportIncident(IncidentType type, String description) {
    final pos = state.currentLocation?.position ?? const LatLng(6.2494, -75.5681);
    final newIncident = IncidentReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: _getIncidentTitle(type),
      description: description,
      position: pos,
      timestamp: DateTime.now(),
    );

    // Publicar a la base de datos en tiempo real en la nube para que otros usuarios lo vean al instante
    _realtimeIncidentService.publishIncident(newIncident);

    state = state.copyWith(
      pulsePoints: state.pulsePoints + 15, // Recompensa gamificada de puntos
    );

    _ttsService.speakInstruction('Gracias por reportar. Has ganado 15 Pulse Points.');
  }

  void voteIncident(String incidentId, bool isPositive) {
    _realtimeIncidentService.voteIncident(incidentId, isPositive);
  }

  String _getIncidentTitle(IncidentType type) {
    switch (type) {
      case IncidentType.police:
        return 'Control Policial';
      case IncidentType.speedCamera:
        return 'Radar de Velocidad';
      case IncidentType.trafficJam:
        return 'Tráfico Pesado';
      case IncidentType.crash:
        return 'Accidente en Vía';
      case IncidentType.hazard:
        return 'Objeto en Vía';
      case IncidentType.construction:
        return 'Obras en Construcción';
      case IncidentType.pothole:
        return 'Hueco / Cráter Peligroso';
      case IncidentType.flooding:
        return 'Zona de Inundación / Lluvia';
      case IncidentType.transitAgent:
        return 'Agente de Tránsito / Retén';
    }
  }

  void _loadInitialMockIncidents() {
    state = state.copyWith(
      activeIncidents: [
        IncidentReport(
          id: 'inc_0',
          type: IncidentType.transitAgent,
          title: 'Agente de Tránsito',
          description: 'Control de movilidad en vía principal',
          position: const LatLng(4.6105, -74.0815),
          timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        IncidentReport(
          id: 'inc_1',
          type: IncidentType.police,
          title: 'Control Policial',
          description: 'Policía visible en carril derecho',
          position: const LatLng(4.6120, -74.0800),
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        IncidentReport(
          id: 'inc_2',
          type: IncidentType.speedCamera,
          title: 'Radar Fijo 80 km/h',
          description: 'Fotomulta activa',
          position: const LatLng(4.6150, -74.0750),
          timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
        IncidentReport(
          id: 'inc_3',
          type: IncidentType.pothole,
          title: 'Hueco / Cráter Peligroso',
          description: 'Hueco grande en carril central',
          position: const LatLng(4.6110, -74.0810),
          timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        ),
        IncidentReport(
          id: 'inc_4',
          type: IncidentType.flooding,
          title: 'Zona de Inundación',
          description: 'Encharcamiento por lluvia en vía',
          position: const LatLng(4.6140, -74.0780),
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
      ],
    );
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});
