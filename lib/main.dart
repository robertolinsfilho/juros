import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/open_repo.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repo = await openRepo();
    repo.purgeExpired();
    runApp(JurosApp(repo: repo));
  } catch (error) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Não foi possível abrir os dados.\n$error')),
      ),
    ));
  }
}
