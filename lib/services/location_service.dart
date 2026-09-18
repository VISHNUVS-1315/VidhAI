import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:vidhai/data/models/user_profile.dart';

class LocationService {
  final Geocoding _geocoding = Geocoding();

  Future<List<Location>> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await _geocoding.locationFromAddress(address);
      return locations;
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<Placemark>> getPlacemarksFromCoordinates(
      double latitude, double longitude) async {
    try {
      final placemarks =
          await _geocoding.placemarkFromCoordinates(latitude, longitude);
      return placemarks;
    } catch (_) {
      return [];
    }
  }


  bool isIndiaCountry(String? country, {String? isoCode}) {
    final normalized = (country ?? '').trim().toLowerCase();
    final iso = (isoCode ?? '').trim().toUpperCase();
    return iso == 'IN' ||
        normalized == 'india' ||
        normalized == 'bharat' ||
        normalized == 'भारत';
  }

  Future<List<AddressSearchResult>> searchIndianAddresses(
    String query, {
    String? state,
    String? district,
  }) async {
    final clean = query.trim();
    if (clean.length < 2) return [];

    final parts = <String>[
      clean,
      if ((district ?? '').trim().isNotEmpty) district!.trim(),
      if ((state ?? '').trim().isNotEmpty) state!.trim(),
      'India',
    ];

    try {
      final locations = await _geocoding.locationFromAddress(parts.join(', '));
      final results = <AddressSearchResult>[];

      for (final loc in locations.take(6)) {
        final placemarks = await _geocoding.placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );
        if (placemarks.isEmpty) continue;

        final pm = placemarks.first;
        if (!isIndiaCountry(pm.country, isoCode: pm.isoCountryCode)) continue;

        final displayParts = <String>[
          if (pm.street != null && pm.street!.isNotEmpty) pm.street!,
          if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
            pm.subLocality!,
          if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
          if (pm.subAdministrativeArea != null &&
              pm.subAdministrativeArea!.isNotEmpty)
            pm.subAdministrativeArea!,
          if (pm.administrativeArea != null &&
              pm.administrativeArea!.isNotEmpty)
            pm.administrativeArea!,
          'India',
        ];

        results.add(
          AddressSearchResult(
            displayText:
                displayParts.isNotEmpty ? displayParts.join(', ') : clean,
            latitude: loc.latitude,
            longitude: loc.longitude,
            city: pm.locality,
            district: pm.subAdministrativeArea,
            state: pm.administrativeArea,
            country: 'India',
            pincode: pm.postalCode,
          ),
        );
      }

      final seen = <String>{};
      return results
          .where((result) => seen.add(result.displayText.toLowerCase()))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<AddressData?> resolveIndianDistrict({
    required String state,
    required String district,
  }) async {
    final cleanState = state.trim();
    final cleanDistrict = district.trim();
    if (cleanState.isEmpty || cleanDistrict.isEmpty) return null;

    try {
      final locations = await _geocoding.locationFromAddress(
        '$cleanDistrict, $cleanState, India',
      );
      if (locations.isEmpty) return null;

      final loc = locations.first;
      final placemarks = await _geocoding.placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );
      if (placemarks.isEmpty) return null;

      final pm = placemarks.first;
      if (!isIndiaCountry(pm.country, isoCode: pm.isoCountryCode)) return null;

      return AddressData(
        fullAddress: '$cleanDistrict, $cleanState, India',
        latitude: loc.latitude,
        longitude: loc.longitude,
        city: pm.locality,
        district: pm.subAdministrativeArea?.trim().isNotEmpty == true
            ? pm.subAdministrativeArea
            : cleanDistrict,
        state: pm.administrativeArea?.trim().isNotEmpty == true
            ? pm.administrativeArea
            : cleanState,
        country: 'India',
        pincode: pm.postalCode,
        isVerified: true,
      );
    } catch (_) {
      return AddressData(
        fullAddress: '$cleanDistrict, $cleanState, India',
        district: cleanDistrict,
        state: cleanState,
        country: 'India',
        isVerified: true,
      );
    }
  }

  Future<AddressData?> searchAndResolveAddress(String query) async {
    if (query.trim().isEmpty) return null;

    try {
      final locations = await _geocoding.locationFromAddress(query);
      if (locations.isEmpty) return null;

      final loc = locations.first;
      final placemarks = await _geocoding.placemarkFromCoordinates(
        loc.latitude,
        loc.longitude,
      );

      if (placemarks.isEmpty) {
        return AddressData(
          fullAddress: query,
          latitude: loc.latitude,
          longitude: loc.longitude,
          isVerified: true,
        );
      }

      final pm = placemarks.first;
      final parts = <String>[
        if (pm.street != null && pm.street!.isNotEmpty) pm.street!,
        if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
          pm.subLocality!,
        if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
        if (pm.administrativeArea != null && pm.administrativeArea!.isNotEmpty)
          pm.administrativeArea!,
        if (pm.country != null && pm.country!.isNotEmpty) pm.country!,
        if (pm.postalCode != null && pm.postalCode!.isNotEmpty) pm.postalCode!,
      ];

      final fullAddress = parts.isNotEmpty ? parts.join(', ') : query;

      return AddressData(
        fullAddress: fullAddress,
        latitude: loc.latitude,
        longitude: loc.longitude,
        city: pm.locality,
        district: pm.subAdministrativeArea,
        state: pm.administrativeArea,
        country: pm.country,
        pincode: pm.postalCode,
        isVerified: true,
      );
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<AddressSearchResult>> searchAddresses(String query) async {
    if (query.trim().length < 3) return [];

    try {
      final locations = await _geocoding.locationFromAddress(query);
      final results = <AddressSearchResult>[];

      for (final loc in locations.take(5)) {
        final placemarks = await _geocoding.placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );
        if (placemarks.isNotEmpty) {
          final pm = placemarks.first;
          final parts = <String>[
            if (pm.street != null && pm.street!.isNotEmpty) pm.street!,
            if (pm.subLocality != null && pm.subLocality!.isNotEmpty)
              pm.subLocality!,
            if (pm.locality != null && pm.locality!.isNotEmpty) pm.locality!,
            if (pm.administrativeArea != null &&
                pm.administrativeArea!.isNotEmpty)
              pm.administrativeArea!,
            if (pm.country != null && pm.country!.isNotEmpty) pm.country!,
          ];
          results.add(AddressSearchResult(
            displayText: parts.isNotEmpty ? parts.join(', ') : query,
            latitude: loc.latitude,
            longitude: loc.longitude,
            city: pm.locality,
            district: pm.subAdministrativeArea,
            state: pm.administrativeArea,
            country: pm.country,
            pincode: pm.postalCode,
          ));
        }
      }
      return results;
    } catch (_) {
      return [];
    }
  }
}

class AddressSearchResult {
  final String displayText;
  final double latitude;
  final double longitude;
  final String? city;
  final String? district;
  final String? state;
  final String? country;
  final String? pincode;

  const AddressSearchResult({
    required this.displayText,
    required this.latitude,
    required this.longitude,
    this.city,
    this.district,
    this.state,
    this.country,
    this.pincode,
  });

  AddressData toAddressData() => AddressData(
        fullAddress: displayText,
        latitude: latitude,
        longitude: longitude,
        city: city,
        district: district,
        state: state,
        country: country,
        pincode: pincode,
        isVerified: true,
      );
}
