import 'package:flutter/material.dart';
import 'database/db_helper.dart';
import 'screens/folder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ensure set up of Database before running app
  await DB.instance.init();
  runApp(const CardOrganizerApp());
}

class CardOrganizerApp extends StatelessWidget {
  const CardOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Card Organizer',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.redAccent,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true, 
        colorSchemeSeed: Colors.redAccent,
        brightness: Brightness.dark,
      ),
      home: const FolderScreen(),
    );
  }
}