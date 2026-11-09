import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores API keys encrypted on the device:
/// - Android: encrypted with a key kept in the Android Keystore.
/// - iOS: saved in the iOS Keychain.
///
/// Keys are stored per provider ("api_key_groq", "api_key_openrouter"), so
/// switching providers does not lose the other key. Keys are never logged.
class SecureKeyStorage {
  SecureKeyStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              // Readable after the phone is unlocked once since boot,
              // and never synced to iCloud or moved to another device.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  String _keyName(String providerId) => 'api_key_$providerId';

  Future<String?> readKey(String providerId) =>
      _storage.read(key: _keyName(providerId));

  Future<void> saveKey(String providerId, String apiKey) =>
      _storage.write(key: _keyName(providerId), value: apiKey);

  Future<void> deleteKey(String providerId) =>
      _storage.delete(key: _keyName(providerId));

  Future<bool> hasKey(String providerId) async =>
      (await readKey(providerId))?.isNotEmpty ?? false;
}
