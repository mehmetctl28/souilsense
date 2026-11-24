import 'sensor_data.dart';

class PumpPolicy {
  static const maxSeconds = 30;
  static const ttlMs = 20000;
  static const dailyLimit = 3;
  static const cooldownMs = 30 * 60 * 1000;
  static const dayMs = 24 * 60 * 60 * 1000;

  /// Counters travel in the same atomic record as the command. No phone-local
  /// counter can reset them on sign-out, reinstall, or a second phone.
  static Map<String, Object?>? next({
    required Object? previous,
    required String commandId,
    required int now,
    required bool requestedState,
    required bool automatic,
    required int seconds,
  }) {
    if (seconds < 1 || seconds > maxSeconds) return null;
    final old = previous is Map ? previous : const {};
    final day = now - now % dayMs;
    final oldDay = SensorData.parseSafeInt(old['dayStart'], fallback: 0);
    final oldCount = SensorData.parseSafeInt(old['autoCount'], fallback: 0);
    final lastAuto = SensorData.parseSafeInt(old['lastAutoAt'], fallback: 0);
    final count = oldDay == day ? oldCount : 0;
    if (oldDay > day) return null;
    if (requestedState &&
        automatic &&
        (count >= dailyLimit || now - lastAuto < cooldownMs)) {
      return null;
    }
    return {
      'protocolVersion': 2,
      'commandId': commandId,
      'requestedState': requestedState,
      'automatic': automatic && requestedState,
      'maxDurationSeconds': seconds,
      'issuedAt': now,
      'expiresAt': now + ttlMs,
      'dayStart': day,
      'autoCount': count + (automatic && requestedState ? 1 : 0),
      'lastAutoAt': automatic && requestedState ? now : lastAuto,
    };
  }
}

class PumpCommandState {
  final bool requestedState;
  final bool actualState;
  final bool actualStateKnown;
  final bool autoWatering;
  final int maxDurationSeconds;
  final int updatedAt;
  final bool timedOut;
  final bool sending;
  final String commandId;
  final String acknowledgedId;
  final String deviceState;
  final String? error;

  const PumpCommandState({
    this.requestedState = false,
    this.actualState = false,
    this.actualStateKnown = false,
    this.autoWatering = false,
    this.maxDurationSeconds = 15,
    this.updatedAt = 0,
    this.timedOut = false,
    this.sending = false,
    this.commandId = '',
    this.acknowledgedId = '',
    this.deviceState = '',
    this.error,
  });

  bool get acknowledged =>
      commandId.isNotEmpty && acknowledgedId == commandId && actualStateKnown;
  bool get isPendingConfirmation =>
      sending ||
      (commandId.isNotEmpty && !acknowledged && !timedOut && error == null);
  bool get completed => acknowledged && deviceState == 'completed';
  bool get isBusy => sending || isPendingConfirmation || actualState;
  String get label {
    if (sending) return 'Komut gönderiliyor';
    if (error != null) return error!;
    if (timedOut) return 'Onay alınamadı; cihaz durumu bilinmiyor';
    if (isPendingConfirmation) return 'Cihaz onayı bekleniyor';
    if (acknowledged && deviceState == 'rejected') {
      return 'Cihaz komutu reddetti';
    }
    if (!actualStateKnown) return 'Cihaz durumu bilinmiyor';
    if (actualState) return 'Pompa çalışıyor';
    if (completed) return 'Sulama tamamlandı';
    return 'Pompa kapalı';
  }

  factory PumpCommandState.fromRecords(
    Map command,
    Map status, {
    bool autoWatering = false,
    bool sending = false,
    bool timedOut = false,
    String? error,
    required int now,
  }) {
    final time = SensorData.normalizeTimestamp(status['updatedAt']);
    final known = status['protocolVersion'] == 2 &&
        time > 0 &&
        now >= time &&
        now - time < 60000;
    return PumpCommandState(
      requestedState: command['requestedState'] == true,
      actualState: known && status['actualState'] == true,
      actualStateKnown: known,
      autoWatering: autoWatering,
      maxDurationSeconds:
          SensorData.parseSafeInt(command['maxDurationSeconds'], fallback: 15),
      updatedAt: SensorData.normalizeTimestamp(command['issuedAt']),
      commandId: command['commandId']?.toString() ?? '',
      acknowledgedId: status['commandId']?.toString() ?? '',
      deviceState: status['state']?.toString() ?? '',
      sending: sending,
      timedOut: timedOut,
      error: error,
    );
  }
}
