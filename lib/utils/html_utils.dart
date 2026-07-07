/// Interface condicional para funções que usam dart:html
/// Web: implementação real  |  Android/iOS: stub no-op
export 'html_utils_stub.dart'
    if (dart.library.html) 'html_utils_web.dart';
