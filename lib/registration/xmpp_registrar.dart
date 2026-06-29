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
    // Abre o canal conectando diretamente na URL estável da Railway
    final channel = WebSocketChannel.connect(
      Uri.parse(UiAccount.wsUrl),
    );

    final completer = Completer<void>();
    final buffer = StringBuffer();
    String stage = 'open';

    channel.stream.listen(
      (data) {
        buffer.write(data.toString());
        final xml = buffer.toString();

        print("Log de Dados Recebidos: $xml"); // Ajuda a monitorar o fluxo no console

        if (stage == 'open' && (xml.contains('<open') || xml.contains('<stream:features>'))) {
          stage = 'get_fields';
          buffer.clear();
          
          // Solicita os campos de registro ao servidor alvo (localhost)
          channel.sink.add(
            '<iq type="get" id="reg1" to="${UiAccount.serverDomain}">'
            '<query xmlns="jabber:iq:register"/>'
            '</iq>',
          );
        } else if (stage == 'get_fields' && xml.contains('jabber:iq:register')) {
          stage = 'registering';
          buffer.clear();
          
          // CORREÇÃO: Substituído 'QUERYEND' pelo fechamento XML correto '</query>'
          channel.sink.add(
            '<iq type="set" id="reg2" to="${UiAccount.serverDomain}">'
            '<query xmlns="jabber:iq:register">'
            '<username>$username</username>'
            '<password>$password</password>'
            '</query>' 
            '</iq>',
          );
        } else if (stage == 'registering') {
          if (xml.contains('type="result"') || xml.contains('registered')) {
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
          completer.completeError(Exception('Conexão encerrada inesperadamente pelo servidor'));
        }
      },
    );

    // Envia o handshake inicial apontando para o domínio 'localhost' configurado na Railway
    channel.sink.add(
      "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
      "to='${UiAccount.serverDomain}' version='1.0'/>",
    );

    try {
      await completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Timeout ao registrar conta'),
      );
    } finally {
      try {
        channel.sink.add("<close xmlns='urn:ietf:params:xml:ns:xmpp-websocket'/>");
        await channel.sink.close();
      } catch (_) {}
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
