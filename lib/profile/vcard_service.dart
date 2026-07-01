import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:simple_chat/account/account_repo.dart';

class VCardService {
  static const int maxImageBytes = 50 * 1024; // ~50KB após compressão

  /// Envia a foto de perfil (já comprimida) como vCard-temp para o servidor.
  /// A imagem fica pública para quem consultar seu vCard (contatos).
  static Future<bool> setAvatar(UiAccount account, Uint8List imageBytes) async {
    if (imageBytes.length > maxImageBytes) {
      throw Exception('Imagem muito grande (máx ${maxImageBytes ~/ 1024}KB após compressão)');
    }

    final base64Image = base64.encode(imageBytes);
    final completer = Completer<bool>();
    const id = 'vcard_set';

    StreamSubscription? sub;
    sub = account.channel?.stream.listen((data) {
      final xml = data.toString();
      if (xml.contains("id='$id'") || xml.contains('id="$id"')) {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.complete(
            xml.contains('type=\'result\'') || xml.contains('type="result"'),
          );
        }
      }
    });

    account.sendXml(
      "<iq type='set' id='$id' xmlns='jabber:client'>"
      "<vCard xmlns='vcard-temp'>"
      "<PHOTO>"
      "<TYPE>image/jpeg</TYPE>"
      "<BINVAL>$base64Image</BINVAL>"
      "</PHOTO>"
      "</vCard>"
      "</iq>",
    );

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => false,
    );
  }

  /// Solicita o vCard (incluindo foto) de um contato pelo JID.
  static Future<Uint8List?> fetchAvatar(UiAccount account, String jid) async {
    final completer = Completer<Uint8List?>();
    const id = 'vcard_get';

    StreamSubscription? sub;
    sub = account.channel?.stream.listen((data) {
      final xml = data.toString();
      if (xml.contains("id='$id'") || xml.contains('id="$id"')) {
        sub?.cancel();
        final match = RegExp(r'<BINVAL>([^<]+)</BINVAL>').firstMatch(xml);
        if (match != null) {
          try {
            final bytes = base64.decode(match.group(1)!);
            if (!completer.isCompleted) completer.complete(bytes);
            return;
          } catch (_) {}
        }
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    account.sendXml(
      "<iq type='get' id='$id' to='$jid' xmlns='jabber:client'>"
      "<vCard xmlns='vcard-temp'/>"
      "</iq>",
    );

    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => null,
    );
  }
}
