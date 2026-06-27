import 'dart:async';
import 'dart:convert';
import 'dart:io';

class XmppRegistrar {
  final String domain;
  final String host;
  final int port;
  final String username;
  final String password;

  XmppRegistrar({
    required this.domain,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  Future<void> register() async {
    Socket? socket;
    try {
      try {
        socket = await SecureSocket.connect(
          host, port,
          onBadCertificate: (_) => true,
          timeout: const Duration(seconds: 10),
        );
      } catch (_) {
        socket = await Socket.connect(
          host, port,
          timeout: const Duration(seconds: 10),
        );
      }

      final completer = Completer<void>();
      final buffer = StringBuffer();
      String stage = 'open';

      socket.listen(
        (data) {
          buffer.write(utf8.decode(data, allowMalformed: true));
          final xml = buffer.toString();

          if (stage == 'open' && xml.contains('stream:features')) {
            stage = 'get_fields';
            buffer.clear();
            socket!.write(
              '<iq type="get" id="reg1">'
              '<query xmlns="jabber:iq:register"/>'
              '</iq>',
            );
          } else if (stage == 'get_fields' &&
              xml.contains('jabber:iq:register')) {
            stage = 'registering';
            buffer.clear();
            socket!.write(
              '<iq type="set" id="reg2">'
              '<query xmlns="jabber:iq:register">'
              '<username>$username</username>'
              '<password>$password</password>'
              '</query>'
              '</iq>',
            );
          } else if (stage == 'registering') {
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
            completer.completeError(
                Exception('Conexão encerrada inesperadamente'));
          }
        },
      );

      socket.write(
        "<?xml version='1.0'?>"
        "<stream:stream xmlns='jabber:client' "
        "xmlns:stream='http://etherx.jabber.org/streams' "
        "to='$domain' version='1.0'>",
      );

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Timeout ao registrar conta'),
      );
    } finally {
      socket?.write('</stream:stream>');
      socket?.destroy();
    }
  }

  String _parseError(String xml) {
    if (xml.contains('conflict')) return 'Usuário já existe';
    if (xml.contains('not-acceptable')) return 'Dados inválidos';
    if (xml.contains('forbidden')) return 'Registro não permitido neste servidor';
    if (xml.contains('not-allowed')) return 'Registro desabilitado neste servidor';
    return 'Erro ao criar conta';
  }
}
