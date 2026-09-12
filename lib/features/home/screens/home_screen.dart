import 'package:flutter/material.dart';
import 'package:vidhai/locale/locale.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('home_title')),
      ),
      body: Center(
        child: Text(loc.welcomeBack),
      ),
    );
  }
}
