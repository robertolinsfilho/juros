import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/data/repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = Repo.open();
  repo.purgeExpired();
  runApp(JurosApp(repo: repo));
}
