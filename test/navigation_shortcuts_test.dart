import 'package:flutter_test/flutter_test.dart';
import 'package:private_agent/services/navigation_shortcuts.dart';

void main() {
  group('Brawl Stars trophy grinding shortcuts', () {
    test('"Juega al brawl stars y gana 50 copas" opens Brawl Stars', () {
      final shortcut = getNavigationShortcut(
        'Juega al brawl stars y gana 50 copas',
      );
      expect(shortcut, isNotNull);
      expect(shortcut!.length, 1);
      expect(shortcut.first.action, 'open_app');
      expect(shortcut.first.params['app_name'], 'Brawl Stars');
    });

    test('"sube 50 copas con el brawler crow" opens Brawl Stars', () {
      final shortcut = getNavigationShortcut(
        'sube 50 copas con el brawler crow',
      );
      expect(shortcut, isNotNull);
      expect(shortcut!.first.params['app_name'], 'Brawl Stars');
    });

    test('"gana 50 copas" opens Brawl Stars via trophy words', () {
      final shortcut = getNavigationShortcut('gana 50 copas');
      expect(shortcut, isNotNull);
      expect(shortcut!.first.params['app_name'], 'Brawl Stars');
    });

    test('"win 50 trophies with crow" opens Brawl Stars', () {
      final shortcut = getNavigationShortcut('win 50 trophies with crow');
      expect(shortcut, isNotNull);
      expect(shortcut!.first.params['app_name'], 'Brawl Stars');
    });

    test('"play brawl stars" opens Brawl Stars', () {
      final shortcut = getNavigationShortcut('play brawl stars');
      expect(shortcut, isNotNull);
      expect(shortcut!.first.params['app_name'], 'Brawl Stars');
    });
  });

  group('Regular app shortcuts', () {
    test('"Open YouTube" opens YouTube', () {
      final shortcut = getNavigationShortcut('Open YouTube');
      expect(shortcut!.first.params['app_name'], 'YouTube');
    });

    test('"Open Settings and turn on WiFi" uses the WiFi shortcut', () {
      final shortcut = getNavigationShortcut('Open Settings and turn on WiFi');
      expect(shortcut, isNotNull);
      expect(shortcut!.length, 2);
      expect(shortcut.first.params['app_name'], 'Settings');
      expect(shortcut[1].params['text'], 'Network & internet');
    });

    test('Spanish "Abre WhatsApp" opens WhatsApp', () {
      final shortcut = getNavigationShortcut('Abre WhatsApp');
      expect(shortcut!.first.params['app_name'], 'WhatsApp');
    });

    test('Spanish "juega al clash royale" maps to Clash Royale', () {
      final shortcut = getNavigationShortcut('juega al clash royale');
      expect(shortcut, isNotNull);
      expect(shortcut!.first.params['app_name'], 'Clash Royale');
    });

    test('"Open Spotify" opens Spotify', () {
      final shortcut = getNavigationShortcut('open spotify');
      expect(shortcut!.first.params['app_name'], 'Spotify');
    });

    test('non-command conversation returns no shortcut', () {
      expect(getNavigationShortcut('What is the weather today?'), isNull);
    });
  });
}
