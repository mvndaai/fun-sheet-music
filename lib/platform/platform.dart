export 'platform_stub.dart'
    if (dart.library.js_interop) 'web/platform_web.dart'
    if (dart.library.io) 'native/platform_native.dart';
