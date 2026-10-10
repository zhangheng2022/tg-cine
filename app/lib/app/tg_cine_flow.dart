import 'package:flutter/widgets.dart';

import '../ui/features/home/view_models/home_view_model.dart';
import '../ui/features/home/views/home_view.dart';

class TgCineFlow extends StatefulWidget {
  const TgCineFlow({super.key});

  @override
  State<TgCineFlow> createState() => _TgCineFlowState();
}

class _TgCineFlowState extends State<TgCineFlow> {
  final _viewModel = HomeViewModel();

  @override
  Widget build(BuildContext context) => HomeView(viewModel: _viewModel);

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
