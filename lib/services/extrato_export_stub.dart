// ─────────────────────────────────────────────────────────────────────────────
// extrato_export_stub.dart — implementação NATIVA (Android/iOS/Desktop)
// Usado em plataformas não-web via importação condicional.
// Utiliza share_plus para compartilhar o arquivo gerado.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Compartilha um arquivo de texto via share_plus no Android/iOS.
/// Salva o conteúdo em um arquivo temporário e abre o share sheet do SO.
Future<void> shareFileNative({
  required List<int> content,
  required String fileName,
  required String mimeType,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(content, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: mimeType)],
    subject: subject,
  );
}

/// Stubs não usados no ambiente nativo — apenas satisfazem a assinatura
/// compartilhada com extrato_export_web.dart.
void downloadFileWeb({
  required String content,
  required String fileName,
  required String mimeType,
}) {
  // Nunca chamado fora da web.
}

// ignore: non_constant_identifier_names
void openHtmlBlob({required String html_, required String fileName}) {
  // Nunca chamado fora da web.
}
