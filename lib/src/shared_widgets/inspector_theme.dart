import 'package:flutter/material.dart';

/// Central color identity for the Inspector UI, inspired by Apidog's
/// flat, bordered, green-accented API-tooling look.
class InspectorTheme {
  InspectorTheme._();

  static const Color primary = Color(0xFF00B87C);

  static const Color darkBackground = Color(0xFF11151A);
  static const Color darkSurface = Color(0xFF171C22);
  static const Color darkBorder = Colors.white12;

  static const Color lightBackground = Color(0xFFF4F6F8);
  static const Color lightSurface = Colors.white;
  static const Color lightBorder = Colors.black12;

  static Color background(bool isDarkMode) =>
      isDarkMode ? darkBackground : lightBackground;

  static Color surface(bool isDarkMode) =>
      isDarkMode ? darkSurface : lightSurface;

  static Color border(bool isDarkMode) =>
      isDarkMode ? darkBorder : lightBorder;

  static const double radius = 10.0;

  // Method badge colors (solid fill, white text)
  static const Color methodGet = Color(0xFF2E90FA);
  static const Color methodPost = Color(0xFF12B76A);
  static const Color methodPut = Color(0xFFF79009);
  static const Color methodPatch = Color(0xFF9E77ED);
  static const Color methodDelete = Color(0xFFF04438);
  static const Color methodWs = Color(0xFF0BA5EC);
  static const Color sse = Color(0xFF0BA5EC);

  // Status badge colors
  static const Color statusOk = Color(0xFF12B76A);
  static const Color statusRedirect = Color(0xFFF79009);
  static const Color statusError = Color(0xFFF04438);
}
