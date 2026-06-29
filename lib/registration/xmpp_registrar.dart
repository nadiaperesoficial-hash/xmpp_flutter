import 'dart:async';
import 'package:simple_chat/account/account_repo.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class XmppRegistrar {
  final String username;
  final String password;

  XmppRegistrar({
    required String domain,
    required String host,
    required int port,
    required this.username,
    required this.password,
  });

  Future<void> register() async {
    final channel = WebSocketChannel.connect(
      Uri.parse(UiAccount.wsUrl),
      protocols: ['xmpp'],
    );

    final completer = Completer<void>();
    final buffer = StringBuffer();
    String stage = 'open';

    channel.stream.listen(
      (data) {
        // Acumula os chunks XML recebidos no stream do WebSocket
        buffer.write(data.toString());
        final xml = buffer.toString();

        if (stage == 'open' && xml.contains('<open')) {
          stage = 'get_fields';
          buffer.clear(); // Limpa apenas após validar a transição de estado
          
          // Solicita os campos de registro ao servidor onyx.im
          channel.sink.add(
            '<iq type="get" id="reg1" to="${UiAccount.serverDomain}">'
            '<query xmlns="jabber:iq:register"/>'
            '</iq>',
          );
        } else if (stage == 'get_fields' && xml.contains('jabber:iq:register')) {
          stage = 'registering';
          buffer.clear();
          
          // CORREÇÃO 1: Substituído 'QUERYEND' pelo fechamento XML correto '</query>'
          channel.sink.add(
            '<iq type="set" id="reg2" to="${UiAccount.serverDomain}">'
            '<query xmlns="jabber:iq:register">'
            '<username>$username</username>'
            '<password>$password</password>'
            '</query>' 
            '</iq>',
          );
        } else if (stage == 'registering') {
          // Intercepta a resposta definitiva do Prosody para o usuário no Flutter
          if (xml.contains('type="result"')) {
            if (!completer.isCompleted) completer.complete();
          } else if (xml.contains('type="error"')) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(_parseError(xml)));
            }
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.completeError(Exception('Conexão encerrada inesperadamente'));
        }
      },
    );

    // Envia a estrofe de abertura forçando o namespace correto de WebSocket XMPP (RFC 7395)
    channel.sink.add(
      "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
      "to='${UiAccount.serverDomain}' version='1.0'/>",
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout ao registrar conta'),
      );
    } finally {
      // Garante o fechamento limpo do canal enviando o handshake de encerramento
      try {
        channel.sink.add("<close xmlns='urn:ietf:params:xml:ns:xmpp-websocket'/>");
        await channel.sink.close();
      } catch (_) {
        // Ignora erros caso o canal já tenha sido fechado pelo servidor remoto
      }
    }
  }

  String _parseError(String xml) {
    if (xml.contains('conflict')) return 'Usuário já existe';
    if (xml.contains('not-acceptable')) return 'Dados inválidos';
    if (xml.contains('forbidden')) return 'Registro não permitido';
    if (xml.contains('not-allowed')) return 'Registro desabilitado';
    return 'Erro ao criar conta';
  }
}
