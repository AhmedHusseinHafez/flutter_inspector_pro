import 'package:flutter/material.dart';

import '../enums/developer_log_level_enum.dart';
import '../enums/requests_methods.dart';

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

  static Color border(bool isDarkMode) => isDarkMode ? darkBorder : lightBorder;

  static const double radius = 10.0;

  // Method badge colors (solid fill, white text)
  static const Color methodGet = Color(0xFF2E90FA);
  static const Color methodPost = Color(0xFF12B76A);
  static const Color methodPut = Color(0xFFF79009);
  static const Color methodPatch = Color(0xFF9E77ED);
  static const Color methodDelete = Color(0xFFF04438);
  static const Color methodQuery = Color(0xFF667085);
  static const Color methodWs = Color(0xFF0BA5EC);
  static const Color sse = Color(0xFF0BA5EC);
  static const Color firebaseMessaging = Color(0xFFF7941D);

  // Developer log level colors.
  static const Color logVerbose = Color(0xFF98A2B3);
  static const Color logDebug = Color(0xFF667085);
  static const Color logInfo = Color(0xFF2E90FA);
  static const Color logWarning = Color(0xFFF79009);
  static const Color logError = Color(0xFFF04438);

  static const Map<DeveloperLogLevel, Color> _logLevelColors = {
    DeveloperLogLevel.verbose: logVerbose,
    DeveloperLogLevel.debug: logDebug,
    DeveloperLogLevel.info: logInfo,
    DeveloperLogLevel.warning: logWarning,
    DeveloperLogLevel.error: logError,
  };

  static Color colorForLogLevel(DeveloperLogLevel level) =>
      _logLevelColors[level] ?? logDebug;

  // Status badge colors
  static const Color statusOk = Color(0xFF12B76A);
  static const Color statusRedirect = Color(0xFFF79009);
  static const Color statusError = Color(0xFFF04438);

  static const Map<RequestMethod, Color> _methodColors = {
    RequestMethod.GET: methodGet,
    RequestMethod.POST: methodPost,
    RequestMethod.PUT: methodPut,
    RequestMethod.PATCH: methodPatch,
    RequestMethod.DELETE: methodDelete,
    RequestMethod.QUERY: methodQuery,
    RequestMethod.WS: methodWs,
  };

  static Color colorForMethod(RequestMethod method) =>
      _methodColors[method] ?? Colors.grey;

  static Color colorForStatusCode(int? statusCode) {
    if (statusCode == null) return statusError;
    if (statusCode > 399) return statusError;
    if (statusCode > 299) return statusRedirect;
    return statusOk;
  }

  // API Intelligence finding severity colors.
  static const Color severityHealthy = Color(0xFF12B76A);
  static const Color severityWatch = Color(0xFF667085);
  static const Color severityOptimizationCandidate = Color(0xFFF79009);
  static const Color severityHighPriority = Color(0xFFF04438);
}
