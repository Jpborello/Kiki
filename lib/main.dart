import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/audio/sound_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lee si los sonidos quedaron silenciados; no hace falta esperarlo.
  SoundService.instance.init();
  runApp(
    const ProviderScope(
      child: KikiDrawApp(),
    ),
  );
}
