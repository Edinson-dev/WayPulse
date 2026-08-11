import 'dart:async';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';
import '../../features/incidents/models/incident_model.dart';

class RealtimeIncidentService {
  final Dio _dio = Dio();
  // Cloud Realtime Database Sync Endpoint (Firebase REST API Serverless Engine)
  static const String _databaseUrl = 'https://flutter-ai-playground-52ad9-default-rtdb.firebaseio.com/incidents';

  final StreamController<List<IncidentReport>> _incidentsStreamController =
      StreamController<List<IncidentReport>>.broadcast();

  Timer? _syncTimer;

  Stream<List<IncidentReport>> get incidentsStream => _incidentsStreamController.stream;

  RealtimeIncidentService() {
    startRealtimeSync();
  }

  void startRealtimeSync() {
    _fetchCloudIncidents();
    // Consultar el estado en vivo de la nube cada 10 segundos
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _fetchCloudIncidents();
    });
  }

  void dispose() {
    _syncTimer?.cancel();
    _incidentsStreamController.close();
  }

  Future<void> _fetchCloudIncidents() async {
    try {
      final response = await _dio.get('$_databaseUrl.json');
      if (response.statusCode == 200 && response.data != null && response.data is Map) {
        final Map<String, dynamic> rawMap = Map<String, dynamic>.from(response.data as Map);
        final List<IncidentReport> cloudList = [];
        final now = DateTime.now();

        rawMap.forEach((key, value) {
          if (value is Map) {
            final map = Map<String, dynamic>.from(value);
            final expiresAtStr = map['expiresAt'] as String?;
            final downvotes = (map['downvotes'] as num?)?.toInt() ?? 0;

            // Filtrado de Base de Datos Limpia (Clean Database):
            // Ignorar reportes expirados (más de 2 horas) o con 2 o más votos de "Ya no está"
            bool isExpired = false;
            if (expiresAtStr != null) {
              final expDate = DateTime.tryParse(expiresAtStr);
              if (expDate != null && expDate.isBefore(now)) {
                isExpired = true;
                _deleteFromCloud(key); // Limpieza automática del documento en la nube
              }
            }

            if (!isExpired && downvotes < 2) {
              final typeStr = map['type'] ?? 'trafficJam';
              IncidentType type;
              switch (typeStr) {
                case 'police':
                  type = IncidentType.police;
                  break;
                case 'speedCamera':
                  type = IncidentType.speedCamera;
                  break;
                case 'crash':
                  type = IncidentType.crash;
                  break;
                case 'hazard':
                  type = IncidentType.hazard;
                  break;
                case 'construction':
                  type = IncidentType.construction;
                  break;
                case 'pothole':
                  type = IncidentType.pothole;
                  break;
                case 'flooding':
                  type = IncidentType.flooding;
                  break;
                case 'transitAgent':
                  type = IncidentType.transitAgent;
                  break;
                default:
                  type = IncidentType.trafficJam;
              }

              cloudList.add(
                IncidentReport(
                  id: key,
                  type: type,
                  title: map['title'] ?? 'Reporte en Vivo',
                  description: map['description'] ?? 'Confirmado por la comunidad WayPulse',
                  position: LatLng(
                    (map['lat'] as num).toDouble(),
                    (map['lng'] as num).toDouble(),
                  ),
                  timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? now,
                ),
              );
            } else if (downvotes >= 2) {
              _deleteFromCloud(key); // Auto-eliminación por votos de la comunidad
            }
          }
        });

        _incidentsStreamController.add(cloudList);
      }
    } catch (_) {}
  }

  Future<void> publishIncident(IncidentReport incident) async {
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 2));

    final payload = {
      'type': incident.type.name,
      'title': incident.title,
      'description': incident.description,
      'lat': incident.position.latitude,
      'lng': incident.position.longitude,
      'timestamp': incident.timestamp.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'upvotes': 1,
      'downvotes': 0,
    };

    try {
      await _dio.post('$_databaseUrl.json', data: payload);
      await _fetchCloudIncidents(); // Refrescar inmediatamente
    } catch (_) {}
  }

  Future<void> voteIncident(String incidentId, bool isPositive) async {
    try {
      if (isPositive) {
        // Confirmación: Extender vigencia y sumar upvote
        await _dio.patch(
          '$_databaseUrl/$incidentId.json',
          data: {
            'expiresAt': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
          },
        );
      } else {
        // Desmentido ("Ya no está"): Incrementar downvotes. Si llega a 2, eliminar de la nube
        final response = await _dio.get('$_databaseUrl/$incidentId/downvotes.json');
        final currentDownvotes = (response.data as num?)?.toInt() ?? 0;
        final newCount = currentDownvotes + 1;

        if (newCount >= 2) {
          await _deleteFromCloud(incidentId);
        } else {
          await _dio.patch(
            '$_databaseUrl/$incidentId.json',
            data: {'downvotes': newCount},
          );
        }
      }
      await _fetchCloudIncidents();
    } catch (_) {}
  }

  Future<void> _deleteFromCloud(String key) async {
    try {
      await _dio.delete('$_databaseUrl/$key.json');
    } catch (_) {}
  }
}
