import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/api_constants.dart';
import 'shared/services/notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  await Supabase.initialize(
    url: ApiConstants.supabaseUrl,
    anonKey: ApiConstants.supabaseAnonKey,
  );

  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox('settings'),
    Hive.openBox('favorites'),
    Hive.openBox('shopping'),
    Hive.openBox('fridge'),
    Hive.openBox('plan'),
    Hive.openBox('skills'),
    Hive.openBox('journal'),
    Hive.openBox('family'),
    Hive.openBox('translations'),
  ]);

  await NotificationService.init();

  await SentryFlutter.init(
    (options) {
      options.dsn = ApiConstants.sentryDsn;
      options.tracesSampleRate = 0.2;
      options.enableAutoSessionTracking = true;
    },
    appRunner: () => runApp(const ProviderScope(child: CookFastApp())),
  );
}
