import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:vital_reg_mobile/core/error/failure.dart';
import 'package:vital_reg_mobile/core/result/result.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/queried_modification.dart';
import 'package:vital_reg_mobile/features/modifications/domain/modifications_repository.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/cubit/modification_form_cubit.dart';
import 'package:vital_reg_mobile/features/modifications/presentation/form/view/modification_form_page.dart';
import 'package:vital_reg_mobile/l10n/failure_l10n.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Loads a queried request ([id]), then shows its form to correct and
/// resend it. [onDone] runs once it's sent, or when the user leaves.
class QueriedModificationPage extends StatefulWidget {
  const QueriedModificationPage({
    required this.kind,
    required this.id,
    required this.onDone,
    super.key,
  });

  final ModificationKind kind;
  final String id;
  final VoidCallback onDone;

  @override
  State<QueriedModificationPage> createState() =>
      _QueriedModificationPageState();
}

class _QueriedModificationPageState extends State<QueriedModificationPage> {
  final _repository = GetIt.instance<ModificationsRepository>();
  Result<QueriedModification>? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _result = null);
    final result = await _repository.queried(widget.kind, widget.id);
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return switch (_result) {
      Ok(value: final queried) => BlocProvider(
        create: (_) =>
            ModificationFormCubit.queried(_repository, queried)
              ..load().ignore(),
        child: ModificationFormView(
          onDone: widget.onDone,
          onExit: widget.onDone,
        ),
      ),
      Err(:final failure) => _Message(failure: failure, onRetry: _load),
      null => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failure.localize(l10n), textAlign: TextAlign.center),
              TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            ],
          ),
        ),
      ),
    );
  }
}
