import 'package:flutter/material.dart';
import '../../../../core/services/pico_placa_service.dart';

class PicoPlacaConfigSheet extends StatefulWidget {
  final int initialDigit;
  final ColombianCity initialCity;
  final Function(int digit, ColombianCity city) onSave;

  const PicoPlacaConfigSheet({
    super.key,
    required this.initialDigit,
    required this.initialCity,
    required this.onSave,
  });

  @override
  State<PicoPlacaConfigSheet> createState() => _PicoPlacaConfigSheetState();
}

class _PicoPlacaConfigSheetState extends State<PicoPlacaConfigSheet> {
  late int _selectedDigit;
  late ColombianCity _selectedCity;

  @override
  void initState() {
    super.initState();
    _selectedDigit = widget.initialDigit;
    _selectedCity = widget.initialCity;
  }

  @override
  Widget build(BuildContext context) {
    final result = PicoPlacaService().checkRestriction(
      plateLastDigit: _selectedDigit,
      city: _selectedCity,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle superior
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDE8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Título e Icono
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFFF6B00),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pico y Placa Inteligente',
                      style: TextStyle(
                        color: Color(0xFF1A1A2E),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Alertas y desvíos automáticos según tu vehículo',
                      style: TextStyle(
                        color: Color(0xFF999EB5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Selección de Ciudad
          const Text(
            'Ciudad de Circulación',
            style: TextStyle(
              color: Color(0xFF444466),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ColombianCity.values.map((city) {
              final isSelected = city == _selectedCity;
              final name = _getCityLabel(city);
              return ChoiceChip(
                label: Text(name),
                selected: isSelected,
                selectedColor: const Color(0xFF1B4FD8),
                backgroundColor: const Color(0xFFF0F0F8),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF444466),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedCity = city);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Selección del Último Dígito de la Placa
          const Text(
            'Último Dígito de la Placa',
            style: TextStyle(
              color: Color(0xFF444466),
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(10, (digit) {
              final isSelected = digit == _selectedDigit;
              return GestureDetector(
                onTap: () => setState(() => _selectedDigit = digit),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1B4FD8) : const Color(0xFFF0F0F8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF1B4FD8) : const Color(0xFFDDDDE8),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF1B4FD8).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$digit',
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Estado resultante en vivo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: result.isRestricted
                  ? const Color(0xFFFFF0F0)
                  : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: result.isRestricted
                    ? const Color(0xFFFF3B30).withValues(alpha: 0.5)
                    : const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  result.isRestricted
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: result.isRestricted
                      ? const Color(0xFFFF3B30)
                      : const Color(0xFF10B981),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.isRestricted
                            ? '🚨 PICO Y PLACA ACTIVO HOY'
                            : '🟢 LIBRE DE PICO Y PLACA HOY',
                        style: TextStyle(
                          color: result.isRestricted
                              ? const Color(0xFF990000)
                              : const Color(0xFF065F46),
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Placa terminada en $_selectedDigit en ${_getCityLabel(_selectedCity)} (${result.timeWindow})',
                        style: const TextStyle(
                          color: Color(0xFF555577),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Botón de Aplicar
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.onSave(_selectedDigit, _selectedCity);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B4FD8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Guardar Configuración',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCityLabel(ColombianCity city) {
    switch (city) {
      case ColombianCity.medellin:
        return 'Medellín';
      case ColombianCity.bogota:
        return 'Bogotá';
      case ColombianCity.cali:
        return 'Cali';
      case ColombianCity.barranquilla:
        return 'Barranquilla';
    }
  }
}
