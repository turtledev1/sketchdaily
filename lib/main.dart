import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'core/config/unsplash_config.dart';
import 'features/notifications/notification_service.dart';
import 'features/prompts/repository/prompt_repository.dart';
import 'features/prompts/repository/unsplash_client.dart';
import 'features/streak/bloc/streak_bloc.dart';
import 'features/streak/repository/streak_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: await getApplicationDocumentsDirectory(),
  );

  await NotificationService.instance.init();
  // Ask for POST_NOTIFICATIONS on Android 13+. Safe to call repeatedly.
  await NotificationService.instance.requestPermissionsIfNeeded();

  final unsplashConfig = UnsplashConfig.fromEnv();
  final unsplashClient = UnsplashClient(config: unsplashConfig);
  final promptRepository = PromptRepository(client: unsplashClient);
  final streakRepository = StreakRepository();
  await streakRepository.init();

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: promptRepository),
        RepositoryProvider.value(value: streakRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => StreakBloc(repository: streakRepository),
          ),
        ],
        child: const SketchDailyApp(),
      ),
    ),
  );
}
