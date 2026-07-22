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

  // ─────────────────────────────────────────────────────────────────────────
  // INIT / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  void init() {
    _tick(); // Compute immediately
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    _fetchWeather();
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

  Future<void> _fetchWeather() async {
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

      // Open-Meteo API (no API key required)
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/weather'
        '?latitude=${pos.latitude}&longitude=${pos.longitude}'
        '&current_weather=true',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final current = data['current_weather'] as Map<String, dynamic>;
        final weatherCode = current['weathercode'] as int;
        final temp = current['temperature'] as num;

        _weather = WeatherData(
          condition: _parseWeatherCode(weatherCode),
          tempCelsius: temp.toDouble(),
          cityName: '', // Open-Meteo doesn't provide city name
        );
        _tick(); // Re-evaluate atmosphere with new weather
      }
    } catch (_) {
      // Weather fetch failed silently — atmosphere falls back to time-based.
    }

    _weatherLoading = false;
    notifyListeners();
  }

  /// Map Open-Meteo WMO weather codes to app conditions.
  /// https://open-meteo.com/en/docs
  String _parseWeatherCode(int code) {
    // Rain: 51-67, 80-82
    if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
      return 'rainy';
    }
    // Snow: 71-77, 85-86
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) {
      return 'snowy';
    }
    // Fog: 45-48
    if (code >= 45 && code <= 48) {
      return 'foggy';
    }
    // Clear: 0
    if (code == 0) {
      return 'clear';
    }
    // Default to clear for other codes (clouds, etc.)
    return 'clear';
  }

  /// Called externally (e.g. from Settings) to refresh weather.
  Future<void> refreshWeather() async {
    await _fetchWeather();
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
