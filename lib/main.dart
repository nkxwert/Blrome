import 'package:flutter/material.dart';

import 'blrome_controller.dart';
import 'browser/browser_screen.dart';
import 'browser/browser_settings.dart';
import 'history/history_store.dart';
import 'storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await HiveStorage.open();
  runApp(BlromeApp(
    controller: BlromeController(storage)..load(),
    settings: BrowserSettings(storage)..load(),
    history: HistoryStore(storage)..load(),
  ));
}

class BlromeApp extends StatelessWidget {
  const BlromeApp({
    super.key,
    required this.controller,
    required this.settings,
    required this.history,
  });

  final BlromeController controller;
  final BrowserSettings settings;
  final HistoryStore history;

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: brightness,
        ),
        visualDensity: VisualDensity.compact,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLROME',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: BrowserScreen(
        controller: controller,
        settings: settings,
        history: history,
      ),
    );
  }
}
