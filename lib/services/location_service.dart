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
      final placemarks = await _geocoding.placemarkFromCoordinates(latitude, longitude);
      return placemarks;
    } catch (_) {
      return [];
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
        if (pm.administrativeArea != null &&
            pm.administrativeArea!.isNotEmpty)
          pm.administrativeArea!,
        if (pm.country != null && pm.country!.isNotEmpty) pm.country!,
        if (pm.postalCode != null && pm.postalCode!.isNotEmpty)
          pm.postalCode!,
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
            if (pm.locality != null && pm.locality!.isNotEmpty)
              pm.locality!,
            if (pm.administrativeArea != null &&
                pm.administrativeArea!.isNotEmpty)
              pm.administrativeArea!,
            if (pm.country != null && pm.country!.isNotEmpty)
              pm.country!,
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
