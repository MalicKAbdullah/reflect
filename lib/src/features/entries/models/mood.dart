import 'package:flutter/material.dart';

/// The 1–5 mood scale and preset mood tags.
abstract final class Mood {
  static const int min = 1;
  static const int max = 5;

  static const List<String> _emojis = ['😞', '😕', '😐', '🙂', '😄'];
  static const List<String> _labels = [
    'Rough',
    'Low',
    'Okay',
    'Good',
    'Great',
  ];

  /// A soft 5-step ramp (coral → amber → mist → sage → teal). Mid-tone
  /// values chosen to read as accents on both light and dark surfaces.
  static const List<Color> _colors = [
    Color(0xFFE57373), // rough — soft coral
    Color(0xFFEFA94E), // low — warm amber
    Color(0xFF94A3B8), // okay — cool mist gray
    Color(0xFF81C784), // good — sage green
    Color(0xFF4DB6AC), // great — calm teal
  ];

  static String emoji(int mood) => _emojis[_clamp(mood) - 1];

  static String label(int mood) => _labels[_clamp(mood) - 1];

  static Color color(int mood) => _colors[_clamp(mood) - 1];

  /// Soft container tint behind mood emoji/chips, tuned per brightness.
  static Color container(int mood, Brightness brightness) => color(mood)
      .withValues(alpha: brightness == Brightness.dark ? 0.26 : 0.16);

  static int _clamp(int mood) => mood.clamp(min, max);

  static const List<String> presetTags = [
    'grateful',
    'anxious',
    'energetic',
    'tired',
    'calm',
    'stressed',
    'happy',
    'sad',
  ];
}
