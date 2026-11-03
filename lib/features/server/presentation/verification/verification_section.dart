import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/widgets/action_feedback.dart';
import '../../../../core/widgets/state_views.dart';
import '../../domain/models.dart';
import '../server_providers.dart';

/// The verification level of the server.
const List<String> verificationLevelNames = <String>[
  'None',
  'Low',
  'Medium',
  'High',
  'Highest',
];

/// Shows and changes the verification level of the server.
class VerificationSection extends ConsumerStatefulWidget {
  const VerificationSection({required this.guildId, super.key});

  final String guildId;

  @override
  ConsumerState<VerificationSection> createState() =>
      _VerificationSectionState();
}

class _VerificationSectionState extends ConsumerState<VerificationSection> {
  bool _saving = false;

  Future<void> _change(int level) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(serverRepositoryProvider)
          .setVerificationLevel(widget.guildId, level);
      ref.invalidate(serverOverviewProvider(widget.guildId));
      ref.invalidate(serverSettingsProvider(widget.guildId));
      if (mounted) {
        showSuccess(
          context,
          'Verification level set to ${verificationLevelNames[level]}.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        showFailure(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(serverOverviewProvider(widget.guildId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Verification gate',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'The level decides how hard a new member has to pass before it can '
          'talk in the server.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        overview.when(
          skipLoadingOnRefresh: false,
          loading: () => const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (Object error, StackTrace stackTrace) => ErrorRetryView(
            failure: error is AppFailure
                ? error
                : UnknownFailure(error.toString()),
            onRetry: () =>
                ref.invalidate(serverOverviewProvider(widget.guildId)),
          ),
          data: (ServerOverview data) {
            final int level = data.verificationLevel;
            return Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: level,
                    decoration: const InputDecoration(
                      labelText: 'Verification level',
                      isDense: true,
                    ),
                    items: List<DropdownMenuItem<int>>.generate(
                      verificationLevelNames.length,
                      (int index) => DropdownMenuItem<int>(
                        value: index,
                        child: Text(verificationLevelNames[index]),
                      ),
                    ),
                    onChanged: _saving
                        ? null
                        : (int? value) {
                            if (value != null) {
                              _change(value);
                            }
                          },
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
