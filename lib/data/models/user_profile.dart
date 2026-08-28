class AddressData {
  final String fullAddress;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? district;
  final String? state;
  final String? country;
  final String? pincode;
  final bool isVerified;

  const AddressData({
    required this.fullAddress,
    this.latitude,
    this.longitude,
    this.city,
    this.district,
    this.state,
    this.country,
    this.pincode,
    this.isVerified = false,
  });

  Map<String, dynamic> toMap() => {
        'fullAddress': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'district': district,
        'state': state,
        'country': country,
        'pincode': pincode,
        'isVerified': isVerified,
      };

  factory AddressData.fromMap(Map<String, dynamic> m) => AddressData(
        fullAddress: m['fullAddress'] ?? '',
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        city: m['city'],
        district: m['district'],
        state: m['state'],
        country: m['country'],
        pincode: m['pincode'],
        isVerified: m['isVerified'] ?? false,
      );
}

class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final String gender;
  final DateTime? dateOfBirth;
  final int age;
  final AddressData? address;
  final String? avatarUrl;
  final String role;
  final bool isEmailVerified;

  const UserProfile({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.gender = '',
    this.dateOfBirth,
    this.age = 0,
    this.address,
    this.avatarUrl,
    this.role = '',
    this.isEmailVerified = false,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'gender': gender,
        'dateOfBirth': dateOfBirth?.toIso8601String(),
        'age': age,
        'address': address?.toMap(),
        'avatarUrl': avatarUrl,
        'role': role,
        'isEmailVerified': isEmailVerified,
        'updatedAt': DateTime.now().toIso8601String(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
        uid: m['uid'] ?? '',
        email: m['email'] ?? '',
        displayName: m['displayName'] ?? '',
        gender: m['gender'] ?? '',
        dateOfBirth: m['dateOfBirth'] != null
            ? DateTime.tryParse(m['dateOfBirth'])
            : null,
        age: m['age'] ?? 0,
        address: m['address'] != null
            ? AddressData.fromMap(Map<String, dynamic>.from(m['address']))
            : null,
        avatarUrl: m['avatarUrl'],
        role: m['role'] ?? '',
        isEmailVerified: m['isEmailVerified'] ?? false,
      );

  UserProfile copyWith({
    String? displayName,
    String? gender,
    DateTime? dateOfBirth,
    int? age,
    AddressData? address,
    String? avatarUrl,
    String? role,
    bool? isEmailVerified,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        gender: gender ?? this.gender,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        age: age ?? this.age,
        address: address ?? this.address,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        role: role ?? this.role,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      );
}
