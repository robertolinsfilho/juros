import 'open_repo_web.dart' if (dart.library.ffi) 'open_repo_io.dart' as impl;
import 'repository.dart';

Future<Repo> openRepo() => impl.openRepo();
