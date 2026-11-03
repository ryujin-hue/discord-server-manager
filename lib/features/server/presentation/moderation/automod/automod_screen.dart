import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/widgets/action_feedback.dart';
import '../../../../../core/widgets/state_views.dart';
import '../../../domain/models.dart';
import '../../server_providers.dart';

/// The kinds of rule Discord supports natively.
enum AutoModKind {
  keyword,
  regex,
  spam,
  mentionSpam;

  String get code => switch (this) {
    AutoModKind.keyword => 'keyword',
    AutoModKind.regex => 'regex',
    AutoModKind.spam => 'spam',
    AutoModKind.mentionSpam => 'mention_spam',
  };

  String get label => switch (this) {
    AutoModKind.keyword => 'Keyword',
    AutoModKind.regex => 'Regular expression',
    AutoModKind.spam => 'Spam',
    AutoModKind.mentionSpam => 'Mention spam',
  };

  String get description => switch (this) {
    AutoModKind.keyword => 'Blocks messages that contain one of the keywords.',
    AutoModKind.regex =>
      'Blocks messages that match one of the regular expressions, for '
          'example a link pattern.',
    AutoModKind.spam => 'Blocks messages that Discord classifies as spam.',
    AutoModKind.mentionSpam => 'Blocks messages with too many mentions.',
  };

  static AutoModKind fromCode(String code) {
    for (final kind in AutoModKind.values) {
      if (kind.code == code) {
        return kind;
      }
    }
    return AutoModKind.keyword;
  }
}

/// The list of the native auto moderation rules of a server.
class AutoModScreen extends ConsumerWidget {
  const AutoModScreen({required this.guildId, super.key});

  final String guildId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(autoModRulesProvider(guildId));

    return Scaffold(
      appBar: AppBar(title: const Text('Auto moderation')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New rule'),
      ),
      body: AsyncStateView<List<AutoModRuleSummary>>(
        value: rules,
        onRetry: () => ref.invalidate(autoModRulesProvider(guildId)),
        data: (List<AutoModRuleSummary> items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.shield_outlined,
              title: 'No auto moderation rule',
              message:
                  'Discord enforces the rules itself, so the bot only needs to '
                  'create them.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(height: 12),
            itemBuilder: (BuildContext context, int index) {
              final rule = items[index];
              return Card(
                child: ListTile(
                  title: Text(rule.name),
                  subtitle: Text(
                    '${AutoModKind.fromCode(rule.kind).label} · '
                    '${rule.enabled ? 'Enabled' : 'Disabled'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) async {
                      if (value == 'delete') {
                        final confirmed = await confirmDestructive(
                          context,
                          title: 'Delete rule',
                          message:
                              'The rule "${rule.name}" is removed from the server.',
                          confirmLabel: 'Delete',
                        );
                        if (!confirmed) {
                          return;
                        }
                        try {
                          await ref
                              .read(serverRepositoryProvider)
                              .deleteAutoModRule(guildId, rule.id);
                          ref.invalidate(autoModRulesProvider(guildId));
                        } on Object catch (error) {
                          if (context.mounted) {
                            showFailure(context, error);
                          }
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<_AutoModDraft>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => const _AutoModEditor(),
    );
    if (result == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(serverRepositoryProvider)
          .createAutoModRule(
            guildId,
            name: result.name,
            kind: result.kind.code,
            keywords: result.keywords,
            regexPatterns: result.regexPatterns,
            mentionTotalLimit: result.mentionLimit,
            allowList: result.allowList,
          );
      ref.invalidate(autoModRulesProvider(guildId));
      if (context.mounted) {
        showSuccess(context, 'The rule was created.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }
}

/// The values the auto moderation editor collects.
class _AutoModDraft {
  const _AutoModDraft({
    required this.name,
    required this.kind,
    required this.keywords,
    required this.regexPatterns,
    required this.mentionLimit,
    required this.allowList,
  });

  final String name;
  final AutoModKind kind;
  final List<String> keywords;
  final List<String> regexPatterns;
  final int mentionLimit;
  final List<String> allowList;
}

class _AutoModEditor extends StatefulWidget {
  const _AutoModEditor();

  @override
  State<_AutoModEditor> createState() => _AutoModEditorState();
}

class _AutoModEditorState extends State<_AutoModEditor> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _keywords = TextEditingController();
  final TextEditingController _patterns = TextEditingController();
  final TextEditingController _allowList = TextEditingController();
  final TextEditingController _mentionLimit = TextEditingController(text: '5');
  AutoModKind _kind = AutoModKind.keyword;

  @override
  void dispose() {
    _name.dispose();
    _keywords.dispose();
    _patterns.dispose();
    _allowList.dispose();
    _mentionLimit.dispose();
    super.dispose();
  }

  List<String> _split(String value) => value
      .split(',')
      .map((String part) => part.trim())
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('New auto moderation rule', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AutoModKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: AutoModKind.values
                  .map(
                    (AutoModKind kind) => DropdownMenuItem<AutoModKind>(
                      value: kind,
                      child: Text(kind.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (AutoModKind? value) {
                if (value != null) {
                  setState(() => _kind = value);
                }
              },
            ),
            const SizedBox(height: 6),
            Text(_kind.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (_kind == AutoModKind.keyword)
              TextField(
                controller: _keywords,
                decoration: const InputDecoration(
                  labelText: 'Keywords',
                  helperText: 'Separated by a comma',
                ),
              ),
            if (_kind == AutoModKind.regex)
              TextField(
                controller: _patterns,
                decoration: const InputDecoration(
                  labelText: 'Regular expressions',
                  helperText:
                      'Separated by a comma. A link filter looks like '
                      'https?://\\S+',
                ),
              ),
            if (_kind == AutoModKind.mentionSpam || _kind == AutoModKind.spam)
              TextField(
                controller: _mentionLimit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum mentions',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _allowList,
              decoration: const InputDecoration(
                labelText: 'Allowed words',
                helperText: 'Separated by a comma',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(
                  _AutoModDraft(
                    name: _name.text.trim(),
                    kind: _kind,
                    keywords: _split(_keywords.text),
                    regexPatterns: _split(_patterns.text),
                    mentionLimit: int.tryParse(_mentionLimit.text) ?? 5,
                    allowList: _split(_allowList.text),
                  ),
                );
              },
              child: const Text('Create rule'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The rules of one server.
final autoModRulesProvider =
    FutureProvider.family<List<AutoModRuleSummary>, String>(
      (ref, guildId) =>
          ref.watch(serverRepositoryProvider).autoModRules(guildId),
    );
