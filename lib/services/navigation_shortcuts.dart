import '../models/saved_skill.dart';

/// Returns predefined navigation steps for common tasks/goals.
///
/// Extracted from [TaskExecutor] so the shortcut logic can be unit-tested
/// without an Android device.
List<ActionStep>? getNavigationShortcut(String goal) {
  final lower = goal.toLowerCase();

  // Settings shortcuts that need a follow-up tap.
  if (lower.contains('dark mode') || lower.contains('dark theme')) {
    return [
      ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
      ActionStep(action: 'click_text', params: {'text': 'Display'}),
    ];
  }
  if (lower.contains('wifi') || lower.contains('wi-fi')) {
    return [
      ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
      ActionStep(
        action: 'click_text',
        params: {'text': 'Network & internet'},
      ),
    ];
  }
  if (lower.contains('bluetooth')) {
    return [
      ActionStep(action: 'open_app', params: {'app_name': 'Settings'}),
      ActionStep(action: 'click_text', params: {'text': 'Connected devices'}),
    ];
  }

  // Trophy-grinding goals target Brawl Stars in this agent:
  // "sube 50 copas", "gana 50 copas", "win 50 trophies"...
  final hasTrophyWord = RegExp(r'\b(?:copas|trofeos|trophies|cups)\b')
      .hasMatch(lower);
  final hasGamingVerb = RegExp(
    r'\b(?:sube|gana|juega|jugar|win|play|raise|get|farm)\b',
  ).hasMatch(lower);
  if (hasTrophyWord && hasGamingVerb) {
    return [
      ActionStep(action: 'open_app', params: {'app_name': 'Brawl Stars'}),
    ];
  }

  final appPatterns = <String, List<String>>{
    'Settings': ['settings', 'brightness', 'display', 'notification'],
    'Play Store': [
      'play store',
      'playstore',
      'download',
      'install app',
      'google play',
    ],
    'YouTube': ['youtube'],
    'WhatsApp': ['whatsapp'],
    'Chrome': ['chrome', 'browse', 'search google'],
    'Camera': ['camera', 'take a photo', 'take photo', 'take a picture'],
    'Gallery': ['gallery', 'photos'],
    'Messages': ['message', 'sms', 'text to'],
    'Phone': ['call', 'dial'],
    'Gmail': ['gmail', 'email'],
    'Maps': ['maps', 'navigate to', 'directions'],
    'Clock': ['alarm', 'timer', 'stopwatch'],
    'Calculator': ['calculator', 'calculate', 'calc'],
    'Brawl Stars': ['brawl stars', 'brawl', 'brawlstars', 'crow', 'brawler'],
  };

  for (final entry in appPatterns.entries) {
    for (final keyword in entry.value) {
      if (lower.contains(keyword)) {
        return [
          ActionStep(action: 'open_app', params: {'app_name': entry.key}),
        ];
      }
    }
  }

  // Generic fallback for "open X"
  final openMatch = RegExp(r'^open\s+([a-zA-Z0-9]+)').firstMatch(lower);
  if (openMatch != null) {
    String app = openMatch.group(1)!;
    app = app[0].toUpperCase() + app.substring(1);
    return [
      ActionStep(action: 'open_app', params: {'app_name': app}),
    ];
  }

  // Spanish gaming/open commands: "juega al brawl stars", "jugar a X",
  // "abre X"
  final esMatch = RegExp(
    r'^(?:juega|jugar|juga|abre|abrir|pon)\s+(?:a|al)?\s+([a-zA-Z0-9]+(?:[ -][a-zA-Z0-9]+)*)',
  ).firstMatch(lower);
  if (esMatch != null) {
    final words = esMatch.group(1)!.split(RegExp(r'[ -]'));
    final app = words
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
    return [
      ActionStep(action: 'open_app', params: {'app_name': app}),
    ];
  }

  return null;
}
