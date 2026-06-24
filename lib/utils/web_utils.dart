/// Interface condicional: usa implementação web na web, stub no mobile/desktop
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
