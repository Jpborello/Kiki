import 'package:flutter_test/flutter_test.dart';
import 'package:kikidraw/core/audio/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundService', () {
    final service = SoundService.instance;

    test('arranca con el silencio guardado', () async {
      SharedPreferences.setMockInitialValues({'kikidraw_sounds_muted': true});
      await service.init();
      expect(service.muted.value, isTrue);
    });

    test('toggleMuted cambia y guarda la preferencia', () async {
      SharedPreferences.setMockInitialValues({});
      await service.init();
      expect(service.muted.value, isFalse);

      await service.toggleMuted();
      expect(service.muted.value, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kikidraw_sounds_muted'), isTrue);

      await service.toggleMuted();
      expect(service.muted.value, isFalse);
    });

    test('cada sonido apunta a un archivo de assets/sounds', () {
      for (final sound in MagicSound.values) {
        expect(sound.assetPath, matches(RegExp(r'^sounds/[a-z_]+\.wav$')));
      }
    });
  });
}
