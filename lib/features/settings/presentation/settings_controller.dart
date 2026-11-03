import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';

/// The repository that stores the user settings.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

/// The settings of the app.
class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  /// Stores the settings and updates the state right away.
  Future<void> save(AppSettings settings) async {
    state = AsyncValue<AppSettings>.data(settings);
    await ref.read(settingsRepositoryProvider).save(settings);
  }

  /// Removes every setting so the app falls back to the defaults.
  Future<void> reset() async {
    await ref.read(settingsRepositoryProvider).reset();
    state = AsyncValue<AppSettings>.data(AppSettings.defaults);
  }
}

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
      SettingsController.new,
    );
