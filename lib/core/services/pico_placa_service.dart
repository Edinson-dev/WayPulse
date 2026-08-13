enum ColombianCity { medellin, bogota, cali, barranquilla, bucaramanga }

class PicoPlacaResult {
  final bool isRestricted;
  final String cityName;
  final String restrictedDigitsStr;
  final String timeWindow;
  final String message;

  PicoPlacaResult({
    required this.isRestricted,
    required this.cityName,
    required this.restrictedDigitsStr,
    required this.timeWindow,
    required this.message,
  });
}

class PicoPlacaService {
  PicoPlacaResult checkRestriction({
    required int plateLastDigit,
    ColombianCity city = ColombianCity.medellin,
    DateTime? dateTime,
  }) {
    final now = dateTime ?? DateTime.now();
    final weekday = now.weekday; // 1 = Mon, 7 = Sun

    // Fines de semana normalmente no hay Pico y Placa particular
    if (weekday == 6 || weekday == 7) {
      return PicoPlacaResult(
        isRestricted: false,
        cityName: _getCityName(city),
        restrictedDigitsStr: 'Sin Restricción',
        timeWindow: 'Fin de semana libre',
        message: '🟢 Sin restricción de Pico y Placa hoy',
      );
    }

    List<int> restrictedDigits = [];
    String timeWindow = '';
    String cityName = _getCityName(city);

    switch (city) {
      case ColombianCity.medellin:
        timeWindow = '5:00 AM - 8:00 PM';
        if (weekday == 1) {
          restrictedDigits = [0, 1];
        } else if (weekday == 2) {
          restrictedDigits = [2, 3];
        } else if (weekday == 3) {
          restrictedDigits = [4, 5];
        } else if (weekday == 4) {
          restrictedDigits = [6, 7];
        } else if (weekday == 5) {
          restrictedDigits = [8, 9];
        }
        break;

      case ColombianCity.bogota:
        timeWindow = '6:00 AM - 9:00 PM';
        final isEvenDay = now.day % 2 == 0;
        restrictedDigits = isEvenDay ? [6, 7, 8, 9, 0] : [1, 2, 3, 4, 5];
        break;

      case ColombianCity.cali:
        timeWindow = '6:00 AM - 7:00 PM';
        if (weekday == 1) {
          restrictedDigits = [7, 8];
        } else if (weekday == 2) {
          restrictedDigits = [9, 0];
        } else if (weekday == 3) {
          restrictedDigits = [1, 2];
        } else if (weekday == 4) {
          restrictedDigits = [3, 4];
        } else if (weekday == 5) {
          restrictedDigits = [5, 6];
        }
        break;

      case ColombianCity.barranquilla:
        timeWindow = 'Sin Restricción Vehículos Particulares';
        restrictedDigits = [];
        break;

      case ColombianCity.bucaramanga:
        timeWindow = '6:00 AM - 8:00 PM';
        if (weekday == 1) {
          restrictedDigits = [3, 4];
        } else if (weekday == 2) {
          restrictedDigits = [5, 6];
        } else if (weekday == 3) {
          restrictedDigits = [7, 8];
        } else if (weekday == 4) {
          restrictedDigits = [9, 0];
        } else if (weekday == 5) {
          restrictedDigits = [1, 2];
        }
        break;
    }

    final isRestricted = restrictedDigits.contains(plateLastDigit);

    return PicoPlacaResult(
      isRestricted: isRestricted,
      cityName: cityName,
      restrictedDigitsStr: restrictedDigits.join(', '),
      timeWindow: timeWindow,
      message: isRestricted
          ? '🚨 Tu placa ($plateLastDigit) TIENE PICO Y PLACA hoy en $cityName ($timeWindow)'
          : '🟢 Tu placa ($plateLastDigit) NO tiene restricción hoy en $cityName',
    );
  }

  String _getCityName(ColombianCity city) {
    switch (city) {
      case ColombianCity.medellin:
        return 'Medellín';
      case ColombianCity.bogota:
        return 'Bogotá';
      case ColombianCity.cali:
        return 'Cali';
      case ColombianCity.barranquilla:
        return 'Barranquilla';
      case ColombianCity.bucaramanga:
        return 'Bucaramanga';
    }
  }
}
