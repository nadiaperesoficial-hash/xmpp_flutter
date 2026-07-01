import 'dart:async';
import 'package:simple_chat/account/xmpp_servers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class XmppRegistrar {
  final String username;
  final String password;
  final String serverDomain;
  final List<String> _wsUrls;

  static const _nsFraming = 'urn:ietf:params:xml:ns:xmpp-framing';

  XmppRegistrar({
    required String domain,
    required String host,
    required int port,
    required this.username,
    required this.password,
  })  : serverDomain = domain,
        _wsUrls = candidateWsUrls(host);

  Future<void> register() async {
    Object? lastError;
    for (final url in _wsUrls) {
      try {
        await _registerOnUrl(url);
        return; // sucesso
      } catch (e) {
        lastError = e;
      }
    }
    throw lastError ?? Exception('Nenhuma porta WebSocket respondeu');
  }

  Future<void> _registerOnUrl(String wsUrl) async {
    final completer = Completer<void>();
    final log = StringBuffer();
    String stage = 'open';

    WebSocketChannel? channel;

    void fail(String msg) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(
            '$msg\n${log.toString().substring(log.length > 700 ? log.length - 700 : 0)}'));
      }
    }

    try {
      channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['xmpp'],
      );

      void send(String xml) {
        log.writeln('[tx] $xml');
        channel!.sink.add(xml);
      }

      channel.stream.listen(
        (data) {
          final xml = data.toString();
          final snippet = xml.length > 300 ? xml.substring(0, 300) : xml;
          log.writeln('[rx] $snippet');

          if (xml.contains('stream:error') || xml.contains('<error')) {
            fail('[server error] $snippet');
            return;
          }

          if (stage == 'open' &&
              (xml.contains('stream:features') || xml.contains('<features'))) {
            stage = 'get_fields';
            send(
              "<iq type='get' id='reg1' to='$serverDomain' xmlns='jabber:client'>"
              "<query xmlns='jabber:iq:register'/>"
              "</iq>",
            );
          } else if (stage == 'get_fields' &&
              xml.contains('jabber:iq:register')) {
            stage = 'registering';
            send(
              "<iq type='set' id='reg2' to='$serverDomain' xmlns='jabber:client'>"
              "<query xmlns='jabber:iq:register'>"
              "<username>$username</username>"
              "<password>$password</password>"
              "</query>"
              "</iq>",
            );
          } else if (stage == 'registering') {
            if (xml.contains('type=\'result\'') || xml.contains('type="result"')) {
              if (!completer.isCompleted) completer.complete();
            } else if (xml.contains('type=\'error\'') || xml.contains('type="error"')) {
              fail('[register] ${_parseError(xml)}');
            }
          }
        },
        onError: (e) => fail('[ws error] $e'),
        onDone: () {
          if (!completer.isCompleted) {
            fail('[done] stage=$stage');
          }
        },
      );

      send("<open xmlns='$_nsFraming' to='$serverDomain' version='1.0'/>");

      await completer.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Timeout ao registrar conta ($wsUrl)\n${log.toString()}'),
      );
    } finally {
      try {
        channel?.sink.add("<close xmlns='$_nsFraming'/>");
        await channel?.sink.close();
      } catch (_) {}
    }
  }

  String _parseError(String xml) {
    if (xml.contains('conflict')) return 'Usuário já existe';
    if (xml.contains('not-acceptable')) return 'Dados inválidos';
    if (xml.contains('forbidden')) return 'Registro não permitido';
    if (xml.contains('not-allowed')) return 'Registro desabilitado';
    return 'Erro ao criar conta: $xml';
  }
}
