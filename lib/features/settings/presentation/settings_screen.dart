import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/action_feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../data/update_service.dart';
import '../domain/app_settings.dart';
import 'settings_controller.dart';

/// The service that checks for a newer release.
final updateServiceProvider = Provider<UpdateService>(
  (ref) => UpdateService(config: ref.watch(appConfigProvider)),
);

/// The settings screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stackTrace) => ErrorRetryView(
          failure: error is AppFailure
              ? error
              : UnknownFailure(error.toString()),
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (AppSettings data) {
          return ListView(
            children: <Widget>[
              const _SectionTitle('Appearance'),
              RadioGroup<AppThemeMode>(
                groupValue: data.themeMode,
                onChanged: (AppThemeMode? value) {
                  if (value != null) {
                    controller.save(data.copyWith(themeMode: value));
                  }
                },
                child: const Column(
                  children: <Widget>[
                    RadioListTile<AppThemeMode>(
                      value: AppThemeMode.system,
                      title: Text('Follow the system'),
                    ),
                    RadioListTile<AppThemeMode>(
                      value: AppThemeMode.light,
                      title: Text('Light'),
                    ),
                    RadioListTile<AppThemeMode>(
                      value: AppThemeMode.dark,
                      title: Text('Dark'),
                    ),
                  ],
                ),
              ),
              const _SectionTitle('Notifications'),
              SwitchListTile(
                value: data.notificationsEnabled,
                title: const Text('Show notifications'),
                subtitle: const Text(
                  'A notification is shown when an upload finishes or fails.',
                ),
                onChanged: (bool value) =>
                    controller.save(data.copyWith(notificationsEnabled: value)),
              ),
              const _SectionTitle('Uploads'),
              ListTile(
                title: const Text('Parallel uploads'),
                subtitle: Text('${data.uploadConcurrency}'),
                trailing: DropdownButton<int>(
                  value: data.uploadConcurrency,
                  items: const <DropdownMenuItem<int>>[
                    DropdownMenuItem<int>(value: 1, child: Text('1')),
                    DropdownMenuItem<int>(value: 2, child: Text('2')),
                    DropdownMenuItem<int>(value: 3, child: Text('3')),
                  ],
                  onChanged: (int? value) {
                    if (value != null) {
                      controller.save(data.copyWith(uploadConcurrency: value));
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text('Maximum file size'),
                subtitle: Text(
                  '${(data.sizeLimitBytes / (1024 * 1024)).toStringAsFixed(0)} MiB per file',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editSizeLimit(context, ref, data),
              ),
              SwitchListTile(
                value: data.groupFiles,
                title: const Text('Group files in one message'),
                subtitle: const Text(
                  'Discord accepts up to ten files in a single message.',
                ),
                onChanged: (bool value) =>
                    controller.save(data.copyWith(groupFiles: value)),
              ),
              if (data.groupFiles)
                ListTile(
                  title: const Text('Files per message'),
                  subtitle: Text('${data.maxFilesPerMessage}'),
                  trailing: DropdownButton<int>(
                    value: data.maxFilesPerMessage,
                    items: List<DropdownMenuItem<int>>.generate(
                      AppSettings.hardMaxFilesPerMessage,
                      (int index) => DropdownMenuItem<int>(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (int? value) {
                      if (value != null) {
                        controller.save(
                          data.copyWith(maxFilesPerMessage: value),
                        );
                      }
                    },
                  ),
                ),
              const _SectionTitle('Storage'),
              ListTile(
                title: const Text('Clear the cached copies'),
                subtitle: const Text(
                  'Removes the copies the app made in its own cache.',
                ),
                trailing: const Icon(Icons.delete_sweep_outlined),
                onTap: () => _clearCache(context),
              ),
              ListTile(
                title: const Text('Reset the settings'),
                trailing: const Icon(Icons.restart_alt),
                onTap: () async {
                  final confirmed = await confirmDestructive(
                    context,
                    title: 'Reset the settings',
                    message: 'Every setting returns to its default value.',
                    confirmLabel: 'Reset',
                  );
                  if (!confirmed) {
                    return;
                  }
                  await controller.reset();
                  if (context.mounted) {
                    showSuccess(context, 'The settings were reset.');
                  }
                },
              ),
              const _SectionTitle('About'),
              const _AboutTile(),
              ListTile(
                title: const Text('Check for updates'),
                trailing: const Icon(Icons.system_update_alt),
                onTap: () => _checkForUpdates(context, ref),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editSizeLimit(
    BuildContext context,
    WidgetRef ref,
    AppSettings data,
  ) async {
    final controller = TextEditingController(
      text: (data.sizeLimitBytes / (1024 * 1024)).round().toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Maximum file size'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'MiB',
            helperText: 'Discord may raise its own limit over time.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text);
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result <= 0) {
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .save(data.copyWith(sizeLimitBytes: result * 1024 * 1024));
  }

  Future<void> _clearCache(BuildContext context) async {
    try {
      final directory = await getTemporaryDirectory();
      var removed = 0;
      for (final entity in directory.listSync()) {
        if (entity is File) {
          entity.deleteSync();
          removed += 1;
        }
      }
      if (context.mounted) {
        showSuccess(context, '$removed cached file(s) removed.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
  }

  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    final service = ref.read(updateServiceProvider);
    final current = ref.read(appConfigProvider);
    try {
      final release = await service.latestRelease();
      if (release == null) {
        if (context.mounted) {
          showFailure(
            context,
            const ValidationFailure(
              'No release was found for this repository.',
            ),
          );
        }
        return;
      }
      const currentVersion = '1.0.0';
      final newer = compareVersions(release.version, currentVersion) > 0;
      if (!context.mounted) {
        return;
      }
      if (newer) {
        final open = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('An update is available'),
            content: Text(
              'Version ${release.version} was released. The release page opens '
              'in the browser, the app never installs an update on its own.',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open the release page'),
              ),
            ],
          ),
        );
        if (open ?? false) {
          await launchUrl(
            Uri.parse(release.url),
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        showSuccess(context, 'The app is up to date.');
      }
    } on Object catch (error) {
      if (context.mounted) {
        showFailure(context, error);
      }
    }
    if (current.githubRepo.isEmpty) {
      if (context.mounted) {
        showFailure(
          context,
          const ValidationFailure('The repository is not configured.'),
        );
      }
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      title: Text('About'),
      subtitle: Text(
        'Discord Server Manager is not affiliated with Discord. It only uses '
        'the public Discord API with your own account.',
      ),
    );
  }
}
