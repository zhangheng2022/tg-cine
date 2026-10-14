import 'package:flutter/foundation.dart';

enum HomeTab { library, history, sources, settings }

class HomeViewModel extends ChangeNotifier {
  HomeTab _selectedTab = HomeTab.library;

  HomeTab get selectedTab => _selectedTab;

  void select(HomeTab tab) {
    if (tab == _selectedTab) return;
    _selectedTab = tab;
    notifyListeners();
  }
}
