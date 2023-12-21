import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPrefsProvider =
    Provider<SharedPreferences>((ref) => throw UnimplementedError());

final brightnessProvider = StateProvider((ref) {
  final prefs = ref.watch(sharedPrefsProvider);
  final value = prefs.getBool('dark_mode');
  final darkMode = (value != null) && value;
  ref.listenSelf((previous, next) {
    prefs.setBool('dark_mode', next == Brightness.dark);
  });
  return darkMode ? Brightness.dark : Brightness.light;
});

final pausedProvider = StateProvider((ref) => false);
final restartProvider = StateProvider((ref) => true);
