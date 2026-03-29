import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ATMOSPHERE STATE
// Computes the current atmosphere every 60 seconds.
// Fetches weather via OpenWeatherMap (free tier) for weather-based overrides.
// Provides background colors, overlay keys, and sun/moon indicator colors.
// ─────────────────────────────────────────────────────────────────────────────

/// Atmosphere keys — match these exactly in AtmosphereOverlay and painters.
class Atmosphere {
  static const String normal = 'Normal';
  static const String golden3pm = 'Golden3PM';
  static const String midnightInk = 'MidnightInk';
  static const String sundayMorning = 'SundayMorning';
  static const String goldenHour = 'GoldenHour';
  static const String rainy = 'Rainy';
  static const String foggy = 'Foggy';
  static const String snowy = 'Snowy';
}

class WeatherData {
  final String condition; // 'clear', 'rainy', 'foggy', 'snowy', 'cloudy'
  final double tempCelsius;
  final String cityName;

  const WeatherData({
    required this.condition,
    required this.tempCelsius,
    required this.cityName,
  });
}

class AtmosphereState extends ChangeNotifier {
  // ── Current atmosphere ────────────────────────────────────────────────────
  String _current = Atmosphere.normal;
  String get current => _current;

  // ── Weather ───────────────────────────────────────────────────────────────
  WeatherData? _weather;
  WeatherData? get weather => _weather;
  bool _weatherLoading = false;
  bool get weatherLoading => _weatherLoading;

  // ── Comfort mode (driven by EditorState, surfaced here for painters) ──────
  bool _isComfortMode = false;
  bool get isComfortMode => _isComfortMode;

  // ── Internal ──────────────────────────────────────────────────────────────
  Timer? _minuteTimer;
  String? _apiKey; // Set from AppState.openWeatherApiKey

  // ─────────────────────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  void init({String? apiKey}) {
    _apiKey = apiKey;
    _tick(); // Compute immediately
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    if (apiKey != null && apiKey.isNotEmpty) {
      _fetchWeather(apiKey);
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ATMOSPHERE COMPUTATION
  // ─────────────────────────────────────────────────────────────────────────

  void _tick() {
    final newAtmosphere = _compute();
    if (newAtmosphere != _current) {
      _current = newAtmosphere;
      notifyListeners();
    }
  }

  String _compute() {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;

    // ── Weather overrides (highest priority) ──────────────────────────────
    if (_weather != null) {
      switch (_weather!.condition) {
        case 'rainy':
          return Atmosphere.rainy;
        case 'foggy':
          return Atmosphere.foggy;
        case 'snowy':
          return Atmosphere.snowy;
      }
    }

    // ── Golden 3PM — The star atmosphere ──────────────────────────────────
    // Active window: 2:55 PM – 3:10 PM (for dust mote easter egg)
    if (hour == 15 || (hour == 14 && minute >= 55)) {
      return Atmosphere.golden3pm;
    }

    // ── Midnight Ink — late night, intimate and protective ─────────────────
    if (hour >= 1 && hour <= 4) {
      return Atmosphere.midnightInk;
    }

    // ── Sunday Morning — parchment, quiet, reflective ─────────────────────
    if (now.weekday == DateTime.sunday && hour >= 7 && hour <= 10) {
      return Atmosphere.sundayMorning;
    }

    // ── Golden Hour — sunrise (5:50–6:10 AM) and sunset (4:50–5:10 PM) ────
    final isGoldenHourMorning = hour == 6 || (hour == 5 && minute >= 50);
    final isGoldenHourEvening = hour == 17 ||
        (hour == 16 && minute >= 50) ||
        (hour == 17 && minute <= 10);
    if (isGoldenHourMorning || isGoldenHourEvening) {
      return Atmosphere.goldenHour;
    }

    return Atmosphere.normal;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEATHER
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _fetchWeather(String apiKey) async {
    _weatherLoading = true;
    notifyListeners();

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _weatherLoading = false;
        notifyListeners();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );

      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather'
        '?lat=${pos.latitude}&lon=${pos.longitude}'
        '&appid=$apiKey&units=metric',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final weatherList = data['weather'] as List<dynamic>;
        final main = (weatherList.first as Map<String, dynamic>)['main']
            .toString()
            .toLowerCase();
        final temp = (data['main'] as Map<String, dynamic>)['temp'] as num;
        final city = data['name'] as String? ?? '';

        _weather = WeatherData(
          condition: _parseCondition(main),
          tempCelsius: temp.toDouble(),
          cityName: city,
        );
        _tick(); // Re-evaluate atmosphere with new weather
      }
    } catch (_) {
      // Weather fetch failed silently — atmosphere falls back to time-based.
    }

    _weatherLoading = false;
    notifyListeners();
  }

  String _parseCondition(String owmMain) {
    if (owmMain.contains('rain') || owmMain.contains('drizzle')) {
      return 'rainy';
    }
    if (owmMain.contains('snow')) return 'snowy';
    if (owmMain.contains('fog') ||
        owmMain.contains('mist') ||
        owmMain.contains('haze')) {
      return 'foggy';
    }
    return 'clear';
  }

  /// Called externally (e.g. from Settings) to refresh weather.
  Future<void> refreshWeather(String apiKey) async {
    _apiKey = apiKey;
    await _fetchWeather(apiKey);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMFORT MODE
  // ─────────────────────────────────────────────────────────────────────────

  void setComfortMode(bool value) {
    if (_isComfortMode == value) return;
    _isComfortMode = value;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COLOR & INDICATOR HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Background color for the current atmosphere + dark mode combination.
  Color backgroundFor(bool dark) {
    if (_isComfortMode) {
      return dark ? AppColors.comfortDark : AppColors.comfortLight;
    }
    return AppColors.atmosphereBg(_current, dark);
  }

  /// Color for the Sun/Moon indicator icon.
  Color sunMoonColor() {
    final isDay = _isDayTime();
    return AppColors.sunMoonColor(_current, isDay);
  }

  bool _isDayTime() {
    final hour = DateTime.now().hour;
    return hour >= 6 && hour < 18;
  }

  bool get isDay => _isDayTime();

  /// Whether the 3PM dust mote easter egg should be active.
  /// Window: 2:55 PM – 3:10 PM.
  bool get isDustMoteActive {
    final now = DateTime.now();
    final hour = now.hour;
    final minute = now.minute;
    return (hour == 14 && minute >= 55) || (hour == 15 && minute <= 10);
  }

  /// Unique key string for AtmosphereOverlay to force rebuild on change.
  /// Combines atmosphere + comfort mode so painters always re-render.
  String get overlayKey =>
      '${_isComfortMode ? "Comfort" : _current}_${_isDayTime()}';
}
