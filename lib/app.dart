import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/view/home_page.dart';

class SketchDailyApp extends StatelessWidget {
  const SketchDailyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SketchDaily',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
