import 'package:flutter_test/flutter_test.dart';
import 'package:tg_cine/ui/features/home/view_models/home_view_model.dart';

void main() {
  test('tab changes notify listeners; selecting the current tab does not', () {
    final viewModel = HomeViewModel();
    addTearDown(viewModel.dispose);
    final selections = <HomeTab>[];
    viewModel.addListener(() => selections.add(viewModel.selectedTab));

    expect(viewModel.selectedTab, HomeTab.library);
    viewModel.select(HomeTab.library);
    viewModel.select(HomeTab.settings);
    viewModel.select(HomeTab.settings);
    viewModel.select(HomeTab.history);
    viewModel.select(HomeTab.library);

    expect(selections, [HomeTab.settings, HomeTab.history, HomeTab.library]);
  });
}
