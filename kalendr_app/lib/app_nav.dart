import 'package:flutter/material.dart';

/// Global navigator key so non-widget code (push tap handlers, background
/// callbacks) can push routes without holding a BuildContext. Wired into
/// MaterialApp in main.dart.
///
/// This lives in its own file to avoid a circular import between main.dart
/// and services that need to navigate (services are already reachable from
/// main.dart through the provider tree).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
