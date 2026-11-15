import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:obtainium/core/logging/app_logger.dart';
import 'package:obtainium/custom_errors.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/utils/push_payload.dart';
import 'package:unifiedpush_platform_interface/data/failed_reason.dart';
import 'package:unifiedpush_platform_interface/data/push_endpoint.dart';
import 'package:unifiedpush_platform_interface/data/push_message.dart';
import 'package:unifiedpush_platform_interface/unifiedpush_platform_interface.dart';
import 'package:workmanager/workmanager.dart';

const String pushTriggerBackgroundArg = '--unifiedpush-bg';
const String _pushInstance = 'obtainium';

class PushTrigger {
  static SettingsProvider? _settings;
  static Future<void>? _initialized;

  static UnifiedPushPlatform get _platform => UnifiedPushPlatform.instance;

  static Future<void> start(
    SettingsProvider settings, {
    bool background = false,
  }) async {
    _settings = settings;
    try {
      await settings.initializeSettings();
      if (!background && !settings.pushTriggerEnabled) {
        return;
      }
      await _ensureInitialized();
      if (!background) {
        await _platform.register(_pushInstance, const [], null, null);
      }
    } catch (e, stack) {
      AppLogger.error(
        e,
        stackTrace: stack,
        message: 'Push trigger: failed to start',
      );
    }
  }

  static Future<void> enable(
    SettingsProvider settings,
    Future<String?> Function(List<String> distributors) pickDistributor,
  ) async {
    _settings = settings;
    await _ensureInitialized();
    if (!await _platform.tryUseCurrentOrDefaultDistributor()) {
      final distributors = await _platform.getDistributors(const []);
      if (distributors.isEmpty) {
        throw ObtainiumError(tr('pushTriggerNoDistributor'));
      }
      final distributor = distributors.length == 1
          ? distributors.first
          : await pickDistributor(distributors);
      if (distributor == null) {
        return;
      }
      await _platform.saveDistributor(distributor);
    }
    settings.pushTriggerEnabled = true;
    await _platform.register(_pushInstance, const [], null, null);
    AppLogger.info('Push trigger: enabled');
  }

  static Future<void> disable(SettingsProvider settings) async {
    _settings = settings;
    settings.pushTriggerEnabled = false;
    settings.pushTriggerEndpoint = null;
    await _ensureInitialized();
    await _platform.unregister(_pushInstance);
    AppLogger.info('Push trigger: disabled');
  }

  static Future<void> _ensureInitialized() async {
    final initialized = _initialized ??= _initializeCallbacks();
    try {
      await initialized;
    } catch (_) {
      _initialized = null;
      rethrow;
    }
  }

  static Future<void> _initializeCallbacks() {
    return _platform.initializeCallback(
      onNewEndpoint: _onNewEndpoint,
      onRegistrationFailed: _onRegistrationFailed,
      onUnregistered: _onUnregistered,
      onMessage: (message, instance) =>
          unawaited(_onMessage(message, instance)),
    );
  }

  static void _onNewEndpoint(PushEndpoint endpoint, String instance) {
    if (instance != _pushInstance) {
      return;
    }
    AppLogger.info(
      'Push trigger: received a new endpoint${endpoint.temporary ? ' (temporary)' : ''}',
    );
    _settings?.pushTriggerEndpoint = endpoint.url;
  }

  static void _onRegistrationFailed(FailedReason reason, String instance) {
    AppLogger.warn('Push trigger: registration failed (${reason.name})');
  }

  static void _onUnregistered(String instance) {
    if (instance != _pushInstance) {
      return;
    }
    AppLogger.info('Push trigger: unregistered by the distributor');
    _settings?.pushTriggerEndpoint = null;
  }

  static Future<void> _onMessage(PushMessage message, String instance) async {
    final settings = _settings;
    if (settings == null || instance != _pushInstance) {
      return;
    }
    try {
      await settings.reloadFromDisk();
      if (!settings.pushTriggerEnabled) {
        AppLogger.info('Push trigger: message ignored (feature is disabled)');
        return;
      }
      final payload = utf8.decode(message.content, allowMalformed: true).trim();
      if (payload.isEmpty || payload.length > maxPushPayloadLength) {
        AppLogger.info('Push trigger: message ignored (empty or too long)');
        return;
      }
      final taskName = 'push_${DateTime.now().millisecondsSinceEpoch}';
      await Workmanager().registerOneOffTask(
        taskName,
        taskName,
        inputData: {pushPayloadParam: payload},
        constraints: Constraints(
          networkType: settings.bgGuardOnWiFi == BgGuardMode.nothing
              ? NetworkType.unmetered
              : NetworkType.connected,
          requiresCharging:
              settings.bgGuardWhileCharging == BgGuardMode.nothing,
          requiresBatteryNotLow: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      AppLogger.info('Push trigger: scheduled a check for "$payload"');
    } catch (e, stack) {
      AppLogger.error(
        e,
        stackTrace: stack,
        message: 'Push trigger: failed to handle a message',
      );
    }
  }
}
