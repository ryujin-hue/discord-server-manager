import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Holds the secrets the user supplies, for example webhook URLs and bot
/// tokens. They are kept in the Android Keystore and never leave the device.
abstract class SecretStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// The secure storage of the platform.
class SecretStore implements SecretStorage {
  SecretStore(this._storage);

  final FlutterSecureStorage _storage;

  static const String _prefix = 'secret.';

  String keyFor(String destinationId) => '$_prefix$destinationId';

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  /// Removes every secret this app stored.
  Future<void> deleteAll() async {
    final all = await _storage.readAll();
    for (final key in all.keys) {
      if (key.startsWith(_prefix)) {
        await _storage.delete(key: key);
      }
    }
  }
}
