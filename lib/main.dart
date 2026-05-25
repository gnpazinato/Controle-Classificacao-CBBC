import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/load_spreadsheet_screen.dart';
import 'theme/cbbc_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const CbbcApp());
}

class CbbcApp extends StatelessWidget {
  const CbbcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Controle de Classificação CBBC',
      debugShowCheckedModeBanner: false,
      theme: buildCbbcTheme(),
      home: const LoadSpreadsheetScreen(),
    );
  }
}
