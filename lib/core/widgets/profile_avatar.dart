import 'package:flutter/material.dart';

class ProfileAvatarPresets {
  ProfileAvatarPresets._();

  static const values = <String>[
    'preset:farmer_1',
    'preset:farmer_2',
    'preset:farmer_3',
    'preset:farmer_4',
    'preset:farmer_5',
    'preset:farmer_6',
  ];

  static const _emoji = <String, String>{
    'preset:farmer_1': '👨🏽‍🌾',
    'preset:farmer_2': '👩🏽‍🌾',
    'preset:farmer_3': '🧑🏽‍🌾',
    'preset:farmer_4': '👨🏻‍🌾',
    'preset:farmer_5': '👩🏻‍🌾',
    'preset:farmer_6': '🧑🏻‍🌾',
  };

  static bool isPreset(String? value) =>
      value != null && _emoji.containsKey(value);

  static String emojiFor(String? value) =>
      _emoji[value] ?? _emoji[values.first]!;
}

class ProfileAvatarView extends StatelessWidget {
  final String? avatarValue;
  final double size;
  final Color backgroundColor;
  final Color borderColor;
  final String fallbackText;

  const ProfileAvatarView({
    super.key,
    required this.avatarValue,
    required this.size,
    required this.backgroundColor,
    required this.borderColor,
    this.fallbackText = 'U',
  });

  @override
  Widget build(BuildContext context) {
    final isPreset = ProfileAvatarPresets.isPreset(avatarValue);
    final hasNetworkImage = (avatarValue ?? '').startsWith('http://') ||
        (avatarValue ?? '').startsWith('https://');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: isPreset
          ? Center(
              child: Text(
                ProfileAvatarPresets.emojiFor(avatarValue),
                style: TextStyle(fontSize: size * 0.54),
              ),
            )
          : hasNetworkImage
              ? Image.network(
                  avatarValue!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallback(),
                )
              : _fallback(),
    );
  }

  Widget _fallback() {
    final clean = fallbackText.trim();
    final text = clean.isEmpty ? 'U' : clean.substring(0, 1).toUpperCase();
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
