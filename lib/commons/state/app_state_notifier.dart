import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../main.dart';
import '../../main/usescases/bundle/bundle.dart';
import 'app_state.dart';

part 'app_state_notifier.g.dart';

@riverpod
class AppStateNotifier extends _$AppStateNotifier {
  @override
  AppState build() {
    // TODO(NMC): Implement return the stored one
    return AppState.initial();
  }

  void navigateTo(String route, {Bundle? bundle}) {
    updateCurrentRoute(route);
    Get.toNamed(route, arguments: bundle);
  }

  void updateCurrentRoute(String route) {
    state = state.copyWith.uiState(
        previousRoute: state.uiState.currentRoute,
        currentRoute: route,
        lastActivityAt: DateTime.now().millisecondsSinceEpoch);
  }

  void viewMainScreen({bool addDelay = false}) {
    if (state.uiState.currentRoute == 'LoginScreen.route') {
      updateCurrentRoute('DashboardScreenBuilder.route');
    }
    while (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState!.pop();
    }
    WidgetsBinding.instance.addPostFrameCallback((duration) {
      navigatorKey.currentState!.pushNamed('MainScreen.route');
    });
  }

  void viewDashboard() {
    updateCurrentRoute('DashboardScreenBuilder.route');

    if (state.prefState.isMobile) {
      navigatorKey.currentState!.pushNamedAndRemoveUntil(
          'DashboardScreenBuilder.route', (Route<dynamic> route) => false);
    }
  }

  void viewSettings() {}
}
