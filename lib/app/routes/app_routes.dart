part of 'app_pages.dart';

abstract class Routes {
  Routes._();
  
  static const SPLASH = _Paths.SPLASH;
  static const LOGIN = _Paths.LOGIN;
  static const HOME = _Paths.HOME;
}

abstract class _Paths {
  _Paths._();
  
  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const HOME = '/home';
}
