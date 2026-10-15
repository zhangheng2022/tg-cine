import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show TextInputAction;
import 'package:forui/forui.dart';

import '../../../../domain/models/telegram_account.dart';
import '../../../../l10n/l10n.dart';
import '../../../core/app_empty_state.dart';
import '../view_models/sources_view_model.dart';

class SourcesView extends StatelessWidget {
  const SourcesView({required this.onOpenSettings, this.viewModel, super.key});

  final VoidCallback onOpenSettings;
  final SourcesViewModel? viewModel;

  @override
  Widget build(BuildContext context) => viewModel == null
      ? AppEmptyState(
          icon: FLucideIcons.folderOpen,
          title: context.l10n.sourcesEmptyTitle,
          description: context.l10n.sourcesEmptyDescription,
          action: context.l10n.connectionDetails,
          onPress: onOpenSettings,
        )
      : ListenableBuilder(
          listenable: viewModel!,
          builder: (context, _) =>
              viewModel!.account.stage == TelegramStage.ready
              ? _SourcePicker(viewModel: viewModel!)
              : _AccountForm(
                  key: ValueKey(viewModel!.account.stage),
                  viewModel: viewModel!,
                ),
        );
}

String _failureText(
  BuildContext context,
  TelegramFailure failure,
) => switch (failure) {
  TelegramFailure.invalidInput => context.l10n.telegramInvalidInput,
  TelegramFailure.authentication => context.l10n.telegramAuthenticationError,
  TelegramFailure.serviceLimited => context.l10n.telegramServiceLimited,
  TelegramFailure.storage => context.l10n.telegramStorageError,
  TelegramFailure.connection => context.l10n.telegramConnectionError,
  TelegramFailure.unavailable => context.l10n.telegramUnavailable,
  TelegramFailure.linkUnsupported => context.l10n.librarySourceLinkUnsupported,
};

class _AccountForm extends StatefulWidget {
  const _AccountForm({required this.viewModel, super.key});
  final SourcesViewModel viewModel;

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _input = TextEditingController();

  void _submit() {
    final value = _input.text;
    _input.clear();
    unawaited(widget.viewModel.submit(value));
  }

  @override
  void dispose() {
    _input.clear();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final l10n = context.l10n;
    final stage = vm.account.stage;
    final editable = [
      TelegramStage.phone,
      TelegramStage.code,
      TelegramStage.password,
      TelegramStage.email,
      TelegramStage.emailCode,
    ].contains(stage);
    final label = switch (stage) {
      TelegramStage.phone => l10n.telegramPhone,
      TelegramStage.code => l10n.telegramCode,
      TelegramStage.password => l10n.telegramPassword,
      TelegramStage.email => l10n.telegramEmail,
      TelegramStage.emailCode => l10n.telegramEmailCode,
      _ => l10n.telegram,
    };
    return SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.telegramConnectTitle,
                  style: context.theme.typography.body.lg.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.telegramConnectBody,
                  style: context.theme.typography.body.md,
                ),
                const SizedBox(height: 28),
                if (editable) ...[
                  FTextField(
                    key: const ValueKey('telegram-auth-input'),
                    control: FTextFieldControl.managed(controller: _input),
                    label: Text(label),
                    hint: stage == TelegramStage.phone
                        ? l10n.telegramPhoneHint
                        : null,
                    obscureText: [
                      TelegramStage.password,
                      TelegramStage.code,
                      TelegramStage.emailCode,
                    ].contains(stage),
                    keyboardType: stage == TelegramStage.phone
                        ? TextInputType.phone
                        : stage == TelegramStage.email
                        ? TextInputType.emailAddress
                        : stage == TelegramStage.password
                        ? TextInputType.text
                        : TextInputType.number,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    enabled: !vm.busy,
                    textInputAction: TextInputAction.done,
                    onSubmit: vm.busy ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (vm.failure != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      vm.account.defaultService &&
                              stage == TelegramStage.failed &&
                              vm.failure == TelegramFailure.authentication
                          ? l10n.telegramServiceAccessExpired
                          : _failureText(context, vm.failure!),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (stage == TelegramStage.unsupported) ...[
                  Text(l10n.telegramUnsupportedAuth),
                  const SizedBox(height: 16),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FButton(
                    key: const ValueKey('telegram-connect-submit'),
                    onPress: vm.busy || stage == TelegramStage.connecting
                        ? null
                        : editable
                        ? _submit
                        : () => unawaited(vm.connect()),
                    child: Text(
                      vm.busy || stage == TelegramStage.connecting
                          ? l10n.telegramConnecting
                          : editable
                          ? l10n.telegramContinue
                          : stage == TelegramStage.failed
                          ? l10n.retry
                          : l10n.telegramConnect,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.telegramLoginPrivacy,
                  style: context.theme.typography.body.sm.copyWith(
                    color: context.theme.colors.mutedForeground,
                  ),
                ),
                if (editable) ...[
                  const SizedBox(height: 12),
                  FButton(
                    variant: FButtonVariant.ghost,
                    onPress: vm.busy ? null : () => unawaited(vm.logout()),
                    child: Text(l10n.telegramCancelLogin),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePicker extends StatefulWidget {
  const _SourcePicker({required this.viewModel});
  final SourcesViewModel viewModel;
  @override
  State<_SourcePicker> createState() => _SourcePickerState();
}

class _SourcePickerState extends State<_SourcePicker> {
  bool _confirmLogout = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.telegramChooseSources,
                        style: context.theme.typography.body.lg.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.telegramSourcesBody,
                        style: context.theme.typography.body.md,
                      ),
                      const SizedBox(height: 20),
                      FTextField(
                        key: const ValueKey('source-search'),
                        label: Text(l10n.telegramSearchSources),
                        control: FTextFieldControl.managed(
                          initial: TextEditingValue(text: vm.query),
                          onChange: (value) => vm.search(value.text),
                        ),
                      ),
                      if (vm.failure != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(_failureText(context, vm.failure!)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: vm.sources.length,
                itemBuilder: (context, index) {
                  final source = vm.sources[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: FCheckbox(
                        key: ValueKey('source-${source.id}'),
                        label: Text(
                          source.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        value: vm.selected.contains(source.id),
                        enabled: !vm.busy,
                        onChange: (value) => vm.select(source.id, value),
                      ),
                    ),
                  );
                },
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (vm.sources.isEmpty && !vm.loadingSources)
                        Text(l10n.telegramNoSources),
                      if (vm.hasMore || vm.failure != null) ...[
                        const SizedBox(height: 12),
                        FButton(
                          variant: FButtonVariant.outline,
                          onPress: vm.loadingSources || vm.busy
                              ? null
                              : () => unawaited(vm.loadSources()),
                          child: Text(
                            vm.loadingSources
                                ? l10n.telegramLoadingSources
                                : l10n.telegramLoadMore,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        l10n.telegramSourcesNote,
                        style: context.theme.typography.body.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FButton(
                            key: const ValueKey('telegram-logout'),
                            variant: FButtonVariant.ghost,
                            mainAxisSize: MainAxisSize.min,
                            onPress: vm.busy
                                ? null
                                : () {
                                    if (_confirmLogout) {
                                      unawaited(vm.logout());
                                    } else {
                                      setState(() => _confirmLogout = true);
                                    }
                                  },
                            child: Text(
                              _confirmLogout
                                  ? l10n.telegramConfirmLogout
                                  : l10n.telegramLogout,
                            ),
                          ),
                          if (_confirmLogout)
                            FButton(
                              variant: FButtonVariant.ghost,
                              mainAxisSize: MainAxisSize.min,
                              onPress: () =>
                                  setState(() => _confirmLogout = false),
                              child: Text(l10n.telegramKeepLogin),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                vm.saved
                    ? l10n.telegramSourcesSaved
                    : l10n.telegramSourcesSelected(vm.selected.length),
                style: context.theme.typography.body.sm,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: FButton(
                  key: const ValueKey('source-save'),
                  mainAxisSize: MainAxisSize.min,
                  onPress: vm.busy ? null : () => unawaited(vm.save()),
                  child: Text(l10n.telegramSaveSources),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
