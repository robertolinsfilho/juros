import 'package:flutter/material.dart';

/// Guarda o endereço atual e avisa o navegador quando a tela muda.
class AppRoutes extends RouterDelegate<Uri> with ChangeNotifier {
  final navigatorKey = GlobalKey<NavigatorState>();
  Uri uri = Uri(path: '/');
  final List<Uri> _back = [];
  WidgetBuilder pageBuilder = _empty;

  static Widget _empty(BuildContext context) => const SizedBox.shrink();

  @override
  Uri get currentConfiguration => uri;

  @override
  Future<void> setInitialRoutePath(Uri configuration) async {
    uri = configuration;
  }

  @override
  Future<void> setNewRoutePath(Uri configuration) async {
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _back.clear();
    uri = configuration;
    notifyListeners();
  }

  void go(Uri next) {
    if (uri.path == next.path) return;
    _back.add(uri);
    uri = next;
    notifyListeners();
  }

  void replace(Uri next) {
    if (uri.path == next.path) return;
    uri = next;
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return true;
    }
    if (_back.isEmpty) return false;
    uri = _back.removeLast();
    notifyListeners();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage(
          key: const ValueKey('root'),
          child: pageBuilder(context),
        ),
      ],
      onDidRemovePage: (page) {},
    );
  }
}

class AppPathParser extends RouteInformationParser<Uri> {
  const AppPathParser();

  @override
  Future<Uri> parseRouteInformation(RouteInformation routeInformation) async {
    final path = routeInformation.uri.path;
    return Uri(path: path.isEmpty ? '/' : path);
  }

  @override
  RouteInformation restoreRouteInformation(Uri configuration) {
    return RouteInformation(uri: configuration);
  }
}
