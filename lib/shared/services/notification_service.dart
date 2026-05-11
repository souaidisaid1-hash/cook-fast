import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/fridge_item.dart';

typedef WeekPlan = Map<String, Map<String, dynamic>>;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'cookfast_main';
  static const _channelName = 'CookFast';

  static const _slotHours = {
    'Petit-déjeuner': (7, 45),
    'Déjeuner': (12, 15),
    'Dîner': (19, 15),
  };

  static const _dayNumbers = {
    'Lundi': 1, 'Mardi': 2, 'Mercredi': 3, 'Jeudi': 4,
    'Vendredi': 5, 'Samedi': 6, 'Dimanche': 7,
  };

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Paris'));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Rappels repas, défis et minuteur de cuisson',
            importance: Importance.high,
          ),
        );
  }

  static Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return result ?? false;
  }

  static NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Rappels repas, défis et minuteur de cuisson',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ── Rappels repas ────────────────────────────────────────────────────────────

  static Future<int> scheduleMealReminders(Map<String, Map<String, dynamic>> plan) async {
    for (int i = 100; i < 200; i++) {
      await _plugin.cancel(i);
    }

    final now = tz.TZDateTime.now(tz.local);
    int count = 0;
    int notifId = 100;

    for (final entry in _dayNumbers.entries) {
      final dayName = entry.key;
      final dayNum = entry.value;
      final slots = plan[dayName];
      if (slots == null) { notifId += 3; continue; }

      for (final slot in ['Petit-déjeuner', 'Déjeuner', 'Dîner']) {
        final recipe = slots[slot];
        if (recipe == null) { notifId++; continue; }

        final (hour, minute) = _slotHours[slot]!;
        final scheduled = _nextWeekday(now, dayNum, hour, minute);

        if (scheduled.isBefore(now)) { notifId++; continue; }

        final recipeTitle = recipe is Map ? (recipe['title'] ?? 'repas') : recipe.toString();
        final emoji = _slotEmoji(slot);

        await _plugin.zonedSchedule(
          notifId,
          '$emoji $slot prévu',
          '$recipeTitle — prépare-toi ! 🍽️',
          scheduled,
          _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        count++;
        notifId++;
      }
    }
    return count;
  }

  static Future<void> cancelMealReminders() async {
    for (int i = 100; i < 200; i++) {
      await _plugin.cancel(i);
    }
  }

  // ── Défi hebdomadaire ────────────────────────────────────────────────────────

  static Future<void> scheduleChallengeReminder() async {
    await _plugin.cancel(200);
    final now = tz.TZDateTime.now(tz.local);
    final nextMonday = _nextWeekday(now, 1, 9, 0);

    await _plugin.zonedSchedule(
      200,
      '🏆 Nouveau défi de la semaine !',
      'Un nouveau défi culinaire t\'attend. Relève-le et gagne des XP !',
      nextMonday,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelChallengeReminder() async {
    await _plugin.cancel(200);
  }

  // ── Alertes expiration frigo ─────────────────────────────────────────────────

  static Future<void> scheduleExpiryAlerts(List<FridgeItem> items) async {
    for (int i = 400; i < 500; i++) { await _plugin.cancel(i); }

    int id = 400;
    final now = tz.TZDateTime.now(tz.local);

    for (final item in items) {
      if (item.expiryDate == null) continue;
      final days = item.daysUntilExpiry!;
      if (days < -1 || days > 3) continue;

      final alertTime = tz.TZDateTime(
        tz.local,
        item.expiryDate!.year,
        item.expiryDate!.month,
        item.expiryDate!.day,
        9, 0,
      );

      final title = days < 0
          ? '🚨 ${item.name} a expiré !'
          : days == 0
              ? '⚠️ ${item.name} expire aujourd\'hui !'
              : '⚠️ ${item.name} expire dans $days jour${days > 1 ? 's' : ''} !';
      const body = 'Pense à l\'utiliser avant qu\'il ne soit trop tard.';

      if (alertTime.isBefore(now)) {
        await _plugin.show(id, title, body, _details);
      } else {
        await _plugin.zonedSchedule(
          id, title, body, alertTime, _details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      id++;
      if (id >= 500) break;
    }
  }

  static Future<void> cancelExpiryAlerts() async {
    for (int i = 400; i < 500; i++) { await _plugin.cancel(i); }
  }

  // ── Minuteur de cuisson ──────────────────────────────────────────────────────

  static Future<void> showTimerDone(String recipeTitle, String stepDesc) async {
    await _plugin.show(
      300,
      '⏱️ Étape terminée !',
      '$recipeTitle — $stepDesc',
      _details,
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static tz.TZDateTime _nextWeekday(
      tz.TZDateTime from, int weekday, int hour, int minute) {
    var date = tz.TZDateTime(
        tz.local, from.year, from.month, from.day, hour, minute);
    while (date.weekday != weekday || !date.isAfter(from)) {
      date = date.add(const Duration(days: 1));
    }
    return date;
  }

  static String _slotEmoji(String slot) => switch (slot) {
        'Petit-déjeuner' => '🌅',
        'Déjeuner' => '☀️',
        'Dîner' => '🌙',
        _ => '🍽️',
      };
}
