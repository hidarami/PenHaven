import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WEATHER SERVICE
// Fetches current weather from OpenWeatherMap free tier.
// AtmosphereState calls this; do not call directly from UI.
// Free tier: 1,000 calls/day, no credit card required.
// Sign up at: https://openweathermap.org/api
// ─────────────────────────────────────────────────────────────────────────────

class WeatherResult {
  final String condition; // 'clear' | 'rainy' | 'foggy' | 'snowy' | 'cloudy'
  final double tempCelsius;
  final String cityName;
  final String description; // Raw OWM description, e.g. "light rain"

  const WeatherResult({
    required this.condition,
    required this.tempCelsius,
    required this.cityName,
    required this.description,
  });
}

class WeatherService {
  WeatherService._();
  static final WeatherService instance = WeatherService._();

  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';

  // ─────────────────────────────────────────────────────────────────────────
  // LOCATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Requests location permission if not already granted.
  /// Returns true if we have usable permission.
  Future<bool> ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<Position?> _getPosition() async {
    final hasPermission = await ensureLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FETCH
  // ─────────────────────────────────────────────────────────────────────────

  /// Fetches weather for the device's current location.
  /// Returns null on any failure (network, permission, bad key).
  /// Atmosphere falls back to time-based logic when null.
  Future<WeatherResult?> fetchCurrent(String apiKey) async {
    if (apiKey.isEmpty) return null;

    final position = await _getPosition();
    if (position == null) return null;

    try {
      final uri = Uri.parse(
        '$_baseUrl'
        '?lat=${position.latitude}'
        '&lon=${position.longitude}'
        '&appid=$apiKey'
        '&units=metric',
      );

      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return _parse(data);
    } catch (_) {
      return null;
    }
  }

  WeatherResult _parse(Map<String, dynamic> data) {
    final weatherList = data['weather'] as List<dynamic>;
    final first = weatherList.first as Map<String, dynamic>;
    final main = (first['main'] as String).toLowerCase();
    final description = (first['description'] as String?) ?? '';
    final mainData = data['main'] as Map<String, dynamic>;
    final temp = (mainData['temp'] as num).toDouble();
    final city = (data['name'] as String?) ?? '';

    return WeatherResult(
      condition: _parseCondition(main, description),
      tempCelsius: temp,
      cityName: city,
      description: description,
    );
  }

  String _parseCondition(String main, String description) {
    if (main.contains('rain') ||
        main.contains('drizzle') ||
        description.contains('rain')) {
      return 'rainy';
    }
    if (main.contains('snow') || description.contains('snow')) {
      return 'snowy';
    }
    if (main.contains('fog') ||
        main.contains('mist') ||
        main.contains('haze') ||
        description.contains('fog')) {
      return 'foggy';
    }
    if (main.contains('cloud')) return 'cloudy';
    return 'clear';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VALIDATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Quick key validation — pings OWM with a dummy location.
  /// Returns true if the key is accepted (200 response).
  Future<bool> validateApiKey(String apiKey) async {
    if (apiKey.isEmpty) return false;
    try {
      final uri = Uri.parse(
        '$_baseUrl?lat=0&lon=0&appid=$apiKey&units=metric',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 6));
      // OWM returns 200 even for 0,0 (middle of Atlantic) with a valid key
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
