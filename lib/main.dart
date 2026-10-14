import 'package:flutter/material.dart';

import 'blrome_controller.dart';
import 'browser/browser_screen.dart';
import 'storage/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = BlromeController(await HiveStorage.open())..load();
  runApp(BlromeApp(controller: controller));
}

class BlromeApp extends StatelessWidget {
  const BlromeApp({super.key, required this.controller});

  final BlromeController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLROME',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: BrowserScreen(controller: controller),
    );
  }
}
