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
    Socket? rawSocket;
    SecureSocket? secureSocket;
    final completer = Completer<void>();
    final buffer = StringBuffer();
    String stage = 'open';

    void onError(Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    void onDone() {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Conexão encerrada inesperadamente'));
      }
    }

    Future<void> handleData(List<int> data, Socket active) async {
      buffer.write(utf8.decode(data, allowMalformed: true));
      final xml = buffer.toString();

      if (stage == 'open' && xml.contains('stream:features')) {
        buffer.clear();
        if (xml.contains('starttls')) {
          stage = 'starttls';
          active.write('<starttls xmlns="urn:ietf:params:xml:ns:xmpp-tls"/>');
        } else {
          stage = 'get_fields';
          active.write('<iq type="get" id="reg1"><query xmlns="jabber:iq:register"/></iq>');
        }
      } else if (stage == 'starttls' && xml.contains('<proceed')) {
        stage = 'upgrading';
        buffer.clear();
        try {
          secureSocket = await SecureSocket.secure(
            active,
            host: host,
            onBadCertificate: (_) => true,
          );
          secureSocket!.listen(
            (d) => handleData(d, secureSocket!),
            onError: onError,
            onDone: onDone,
          );
          stage = 'reopen';
          secureSocket!.write(
            "<?xml version='1.0'?><stream:stream xmlns='jabber:client' "
            "xmlns:stream='http://etherx.jabber.org/streams' "
            "to='$domain' version='1.0'>",
          );
        } catch (e) {
          onError(Exception('Falha TLS: $e'));
        }
      } else if (stage == 'reopen' && xml.contains('stream:features')) {
        stage = 'get_fields';
        buffer.clear();
        secureSocket?.write('<iq type="get" id="reg1"><query xmlns="jabber:iq:register"/></iq>');
      } else if (stage == 'get_fields' && xml.contains('jabber:iq:register')) {
        stage = 'registering';
        buffer.clear();
        active.write(
          '<iq type="set" id="reg2"><query xmlns="jabber:iq:register">'
          '<username>$username</username>'
          '<password>$password</password>'
          '</query></iq>',
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
    }

    try {
      rawSocket = await Socket.connect(host, port,
          timeout: const Duration(seconds: 15));

      rawSocket.listen(
        (d) => handleData(d, rawSocket!),
        onError: onError,
        onDone: onDone,
      );

      rawSocket.write(
        "<?xml version='1.0'?><stream:stream xmlns='jabber:client' "
        "xmlns:stream='http://etherx.jabber.org/streams' "
        "to='$domain' version='1.0'>",
      );

      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout ao registrar conta'),
      );
    } finally {
      try { secureSocket?.write('</stream:stream>'); } catch (_) {}
      try { rawSocket?.write('</stream:stream>'); } catch (_) {}
      secureSocket?.destroy();
      rawSocket?.destroy();
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
