import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muslimku/core/network/api_service.dart';
import 'package:muslimku/features/location/domain/default_city.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The city of the prayer schedule, saved on the phone, and the city search.
final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);

class LocationState {
  LocationState({
    this.selectedCityId,
    this.selectedCityName,
    this.searchResults = const [],
    this.isSearching = false,
    this.error,
  });

  final String? selectedCityId;
  final String? selectedCityName;
  final List<Map<String, dynamic>> searchResults;
  final bool isSearching;
  final String? error;

  /// The chosen city, null until the user picks one.
  String? get activeCityId => selectedCityId;
  String? get activeCityName => selectedCityName;

  /// The city to use: the chosen one, else [DefaultCity].
  String get cityId => selectedCityId ?? DefaultCity.id;
  String get cityName => selectedCityName ?? DefaultCity.apiName;

  LocationState copyWith({
    String? selectedCityId,
    String? selectedCityName,
    List<Map<String, dynamic>>? searchResults,
    bool? isSearching,
    String? error,
  }) {
    return LocationState(
      selectedCityId: selectedCityId ?? this.selectedCityId,
      selectedCityName: selectedCityName ?? this.selectedCityName,
      searchResults: searchResults ?? this.searchResults,
      isSearching: isSearching ?? this.isSearching,
      error: error,
    );
  }
}

class LocationNotifier extends Notifier<LocationState> {
  late ApiService _apiService;

  @override
  LocationState build() {
    _apiService = ref.read(apiServiceProvider);
    unawaited(_loadSavedLocation());
    return LocationState();
  }

  Future<void> _loadSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCityId = prefs.getString('selectedCityId');
    final savedCityName = prefs.getString('selectedCityName');

    state = state.copyWith(
      selectedCityId: savedCityId,
      selectedCityName: savedCityName,
    );
  }

  Future<void> searchCities(String keyword) async {
    if (keyword.isEmpty) {
      state = state.copyWith(searchResults: [], error: null);
      return;
    }

    state = state.copyWith(isSearching: true, error: null);

    try {
      final results = await _apiService.searchCities(keyword);
      state = state.copyWith(searchResults: results ?? [], isSearching: false);
    } catch (e) {
      state = state.copyWith(isSearching: false, error: 'Gagal mencari kota');
    }
  }

  Future<void> selectCity(String cityId, String cityName) async {
    state = state.copyWith(
      selectedCityId: cityId,
      selectedCityName: cityName,
      searchResults: [],
      error: null,
    );
    await _saveSelectedLocation();
    _notifyLocationChanged();
  }

  Future<void> _saveSelectedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.selectedCityId != null && state.selectedCityName != null) {
      await prefs.setString('selectedCityId', state.selectedCityId!);
      await prefs.setString('selectedCityName', state.selectedCityName!);
    }
  }

  void clearSearchResults() {
    state = state.copyWith(searchResults: []);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void _notifyLocationChanged() {
    state = state.copyWith();
  }
}
