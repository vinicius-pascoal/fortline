import 'package:flutter/material.dart';
import 'core/colors.dart';
import 'core/save_manager.dart';
import 'ui/map_select_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final save = await SaveManager.load();
  runApp(FortlineApp(save: save));
}

class FortlineApp extends StatelessWidget {
  final SaveManager save;
  const FortlineApp({super.key, required this.save});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '�ltima Muralha',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RuneColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: RuneColors.accent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E2238),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      home: MapSelectScreen(save: save),
    );
  }
}
