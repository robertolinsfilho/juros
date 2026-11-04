import 'notify_web.dart' if (dart.library.ffi) 'notify_io.dart';

export 'notify_web.dart' if (dart.library.ffi) 'notify_io.dart' show publishPaymentNotices, noticePermission;
