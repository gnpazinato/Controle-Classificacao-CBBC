import 'package:flutter/material.dart';

import 'screens/load_spreadsheet_screen.dart';
import 'theme/cbbc_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem trava de orientação: tablet/celular giram livremente entre retrato
  // e paisagem. Em telas largas as informações ficam mais organizadas
  // (nomes longos não cortam) — manter as duas opções abertas.
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
