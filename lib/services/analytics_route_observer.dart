// lib/services/analytics_route_observer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_test_app/services/analytics_service.dart';

/// Central screen-view telemetry: every named route push emits one
/// `screen_view` event (fire-and-forget). No GPS, no PII — route name only.
/// Registered once in MaterialApp.navigatorObservers.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver();
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      unawaited(AnalyticsService.logEvent(
        eventName: AnalyticsEvents.screenView,
        eventData: AnalyticsEventBuilder.screenView(screen: name),
      ));
    }
  }
}
