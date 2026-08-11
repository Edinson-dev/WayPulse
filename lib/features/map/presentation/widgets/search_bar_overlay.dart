import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/mapbox_geocoding_service.dart';
import '../../../navigation/providers/navigation_provider.dart';

class SearchBarOverlay extends ConsumerStatefulWidget {
  final Function(LatLng position, String name) onPlaceSelected;
  final Function(bool isSearching)? onSearchingStateChanged;

  const SearchBarOverlay({
    super.key,
    required this.onPlaceSelected,
    this.onSearchingStateChanged,
  });

  @override
  ConsumerState<SearchBarOverlay> createState() => _SearchBarOverlayState();
}

class _SearchBarOverlayState extends ConsumerState<SearchBarOverlay> {
  final MapboxGeocodingService _geocodingService = MapboxGeocodingService();
  final TextEditingController _controller = TextEditingController();
  List<SearchLocationResult> _searchResults = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      widget.onSearchingStateChanged?.call(false);
      return;
    }

    setState(() => _isLoading = true);
    final userPos = ref.read(navigationProvider).currentLocation?.position;
    final results =
        await _geocodingService.searchPlaces(query, proximity: userPos);
    setState(() {
      _searchResults = results;
      _isLoading = false;
    });
    widget.onSearchingStateChanged?.call(_searchResults.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationProvider);
    final navNotifier = ref.read(navigationProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chips de modo de transporte — estilo Waze claro
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTransportChip(
                mode: TransportMode.car,
                icon: Icons.directions_car_rounded,
                label: 'Auto',
                selectedMode: navState.selectedTransportMode,
                onSelect: (m) => navNotifier.setTransportMode(m),
              ),
              _buildTransportChip(
                mode: TransportMode.moto,
                icon: Icons.two_wheeler_rounded,
                label: 'Moto',
                selectedMode: navState.selectedTransportMode,
                onSelect: (m) => navNotifier.setTransportMode(m),
              ),
              _buildTransportChip(
                mode: TransportMode.bike,
                icon: Icons.pedal_bike_rounded,
                label: 'Bici',
                selectedMode: navState.selectedTransportMode,
                onSelect: (m) => navNotifier.setTransportMode(m),
              ),
              _buildTransportChip(
                mode: TransportMode.walk,
                icon: Icons.directions_walk_rounded,
                label: 'A pie',
                selectedMode: navState.selectedTransportMode,
                onSelect: (m) => navNotifier.setTransportMode(m),
              ),
              _buildTransportChip(
                mode: TransportMode.transit,
                icon: Icons.directions_bus_rounded,
                label: 'Bus',
                selectedMode: navState.selectedTransportMode,
                onSelect: (m) => navNotifier.setTransportMode(m),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Barra de búsqueda — blanca estilo Waze / Google Maps
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
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
              const Icon(
                Icons.search_rounded,
                color: Color(0xFF999EB5),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (query) {
                    if (_searchResults.isNotEmpty) {
                      final first = _searchResults.first;
                      FocusScope.of(context).unfocus();
                      widget.onPlaceSelected(first.position, first.title);
                      _controller.clear();
                      setState(() => _searchResults = []);
                      widget.onSearchingStateChanged?.call(false);
                    }
                  },
                  style: const TextStyle(
                    color: Color(0xFF1A1A2E),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: '¿A dónde quieres ir?',
                    hintStyle: TextStyle(
                      color: Color(0xFFAAAFC0),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1B4FD8),
                  ),
                )
              else if (_controller.text.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() => _searchResults = []);
                    widget.onSearchingStateChanged?.call(false);
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDDDDE8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF666680),
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Dropdown de resultados — blanco
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(
                  color: Color(0xFFEEEEF5),
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(0xFFF0F0F8),
                      child: Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1B4FD8),
                        size: 18,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      item.address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF999EB5),
                        fontSize: 12,
                      ),
                    ),
                    onTap: () {
                      FocusScope.of(context).unfocus();
                      widget.onPlaceSelected(item.position, item.title);
                      _controller.clear();
                      setState(() => _searchResults = []);
                      widget.onSearchingStateChanged?.call(false);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTransportChip({
    required TransportMode mode,
    required IconData icon,
    required String label,
    required TransportMode selectedMode,
    required Function(TransportMode) onSelect,
  }) {
    final isSelected = mode == selectedMode;
    return GestureDetector(
      onTap: () => onSelect(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1B4FD8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0xFF1B4FD8).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF666680),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF444466),
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
