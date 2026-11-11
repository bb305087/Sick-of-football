import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _storageVersionKey = 'storage_version';
  static const _currentStorageVersion = '2';
  static const _installationMarkerKey = 'installation_initialized';

  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    sharedPreferencesName: 'SickOfFootballSecureStorage',
  );
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.unlocked_this_device,
  );

  final FlutterSecureStorage _storage;
  final FlutterSecureStorage? _legacyStorage;
  Future<SharedPreferences>? _preferences;
  Future<void>? _installationCheck;
  Future<void>? _migration;

  SecureStorageService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: _androidOptions,
            iOptions: _iosOptions,
          ),
      _legacyStorage = storage == null
          ? const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked,
              ),
            )
          : null;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _ensureInstallationInitialized();
    await _ensureMigrated();
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> readAccessToken() async {
    await _ensureInstallationInitialized();
    await _ensureMigrated();
    return _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() async {
    await _ensureInstallationInitialized();
    await _ensureMigrated();
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _ensureInstallationInitialized();
    await _ensureMigrated();
    await _clearStoredTokens();
    await _storage.write(
      key: _storageVersionKey,
      value: _currentStorageVersion,
    );
  }

  Future<void> _ensureInstallationInitialized() {
    return _installationCheck ??= _initializeInstallation();
  }

  Future<void> _initializeInstallation() async {
    final preferences = await (_preferences ??=
        SharedPreferences.getInstance());
    final initialized = preferences.getBool(_installationMarkerKey) ?? false;
    if (!initialized) {
      await _clearStoredTokens();
      await preferences.setBool(_installationMarkerKey, true);
    }
  }

  Future<void> _clearStoredTokens() async {
    final operations = <Future<void>>[
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _storageVersionKey),
    ];
    final legacyStorage = _legacyStorage;
    if (legacyStorage != null) {
      operations.addAll([
        legacyStorage.delete(key: _accessTokenKey),
        legacyStorage.delete(key: _refreshTokenKey),
        legacyStorage.delete(key: _storageVersionKey),
      ]);
    }
    await Future.wait(operations);
  }

  Future<void> _ensureMigrated() {
    return _migration ??= _migrateLegacyTokens();
  }

  Future<void> _migrateLegacyTokens() async {
    final legacyStorage = _legacyStorage;
    if (legacyStorage == null) {
      return;
    }

    final version = await _storage.read(key: _storageVersionKey);
    if (version == _currentStorageVersion) {
      return;
    }

    for (final key in [_accessTokenKey, _refreshTokenKey]) {
      final currentValue = await _storage.read(key: key);
      final legacyValue = await legacyStorage.read(key: key);
      final value = currentValue ?? legacyValue;

      if (value != null) {
        await _storage.write(key: key, value: value);
      }

      if (defaultTargetPlatform == TargetPlatform.android &&
          legacyValue != null) {
        await legacyStorage.delete(key: key);
      }
    }

    await _storage.write(
      key: _storageVersionKey,
      value: _currentStorageVersion,
    );
  }
}
