import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  int _currentTab = 0;

  int get currentTab => _currentTab;

  void setTab(int index) {
    _currentTab = index;
    notifyListeners();
  }

  /// Triggers a refresh notification to force active views to reload their database queries.
  void refresh() {
    notifyListeners();
  }
}
