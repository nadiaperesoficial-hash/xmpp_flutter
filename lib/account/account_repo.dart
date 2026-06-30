import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:simple_chat/account/xmpp_servers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
}

class XmppAccount {
  final String username;
  final String fullJid;
  final String domain;
  final String password;
  final int port;

  XmppAccount(this.username, this.fullJid, this.domain, this.password, this.port);
}

class UiAccount {
  final XmppAccount account;
  WebSocketChannel? _channel;
  final _stateSubject = BehaviorSubject<AccountState>();

  // Mantidos por compatibilidade com código existente (ex: xmpp_registrar.dart).
  // Apontam para o servidor primário (Railway), porta 443.
  static const wsUrl = 'wss://prosody-server-production.up.railway.app/xmpp-websocket';
  static const serverDomain = 'prosody-server-production.up.railway.app';

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  WebSocketChannel? get channel => _channel;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);
  void sendXml(String xml) => _channel?.sink.add(xml);

  @override
  bool operator ==(Object other) =>
      other is UiAccount &&
      account.username == other.account.username &&
      account.domain == other.account.domain;

  @override
  int get hashCode => Object.hash(account.username, account.domain);

  UiAccount(this.account);
}

class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  // namespace correto conforme RFC 7395
  static const _nsFraming = 'urn:ietf:params:xml:ns:xmpp-framing';

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);
    uiAccount.accountState = AccountRegistering(account: account);

    final domain = account.domain.isNotEmpty ? account.domain : UiAccount.serverDomain;
    final urls = candidateWsUrls(domain);
    _connectWithFallback(uiAccount, urls, 0, StringBuffer());
    return uiAccount;
  }

  /// Tenta conectar usando a lista de URLs candidatas (443 primeiro, depois 5280...).
  /// Se uma falhar (erro de conexão ou stream:error logo no início), tenta a próxima.
  void _connectWithFallback(
    UiAccount uiAccount,
    List<String> urls,
    int index,
    StringBuffer log,
  ) {
    if (index >= urls.length) {
      uiAccount.accountState = AccountUnregistered(
        account: uiAccount.account,
        message: '[connect error] Nenhuma porta funcionou.\n${log.toString()}',
      );
      return;
    }

    final url = urls[index];
    log.writeln('[info] tentando $url');

    bool authenticated = false;
    bool bound = false;
    bool movedOn = false;

    void tryNext(String reason) {
      if (movedOn) return;
      movedOn = true;
      log.writeln('[fallback] $reason -> próxima porta');
      _connectWithFallback(uiAccount, urls, index + 1, log);
    }

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url), protocols: ['xmpp']);
      uiAccount._channel = channel;

      void send(String xml) {
        log.writeln('[tx] $xml');
        channel.sink.add(xml);
      }

      void fail(String msg) {
        uiAccount.accountState = AccountUnregistered(
          account: uiAccount.account,
          message: '$msg\n${log.toString().substring(log.length > 600 ? log.length - 600 : 0)}',
        );
      }

      channel.stream.listen(
        (data) {
          final xml = data.toString();
          final snippet = xml.length > 300 ? xml.substring(0, 300) : xml;
          log.writeln('[rx] $snippet');

          if (xml.contains('stream:error') || xml.contains('<error')) {
            // Se ainda não autenticou, pode ser problema desta porta/servidor:
            // tenta a próxima antes de desistir.
            if (!authenticated) {
              tryNext('[server error] $snippet');
            } else {
              fail('[server error] $snippet');
            }
            return;
          }

          if (!authenticated) {
            if (xml.contains('PLAIN') ||
                xml.contains('stream:features') ||
                xml.contains('<features')) {
              final creds = base64.encode(
                utf8.encode('\x00${uiAccount.account.username}\x00${uiAccount.account.password}'),
              );
              send(
                "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
                "mechanism='PLAIN'>$creds</auth>",
              );
            } else if (xml.contains('<success')) {
              authenticated = true;
              movedOn = true; // não tenta outra porta depois de autenticar
              send("<open xmlns='$_nsFraming' to='${uiAccount.account.domain}' version='1.0'/>");
            } else if (xml.contains('<failure')) {
              movedOn = true;
              fail('[auth] Usuário ou senha incorretos');
            } else if (xml.contains('<open')) {
              // open recebido, aguarda features
            }
          } else if (!bound) {
            if (xml.contains('stream:features') ||
                xml.contains('<features') ||
                xml.contains('<open')) {
              send(
                "<iq type='set' id='bind1'>"
                "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
                "<resource>simple_chat</resource>"
                "</bind>"
                "</iq>",
              );
            } else if (xml.contains('bind') && xml.contains('result')) {
              send(
                "<iq type='set' id='sess1'>"
                "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
                "</iq>",
              );
            } else if (xml.contains('sess1') ||
                (xml.contains('result') && xml.contains('sess'))) {
              bound = true;
              send("<presence/>");
              uiAccount.accountState = AccountRegistered(account: uiAccount.account);
            }
          }
        },
        onError: (e) {
          if (!authenticated) {
            tryNext('[ws error] $e');
          } else {
            fail('[ws error] $e');
          }
        },
        onDone: () {
          if (!bound) {
            if (!authenticated) {
              tryNext('[done] conexão fechada antes de autenticar');
            } else {
              fail('[done] auth=$authenticated bound=$bound');
            }
          }
        },
      );

      send("<open xmlns='$_nsFraming' to='${uiAccount.account.domain}' version='1.0'/>");
    } catch (e) {
      tryNext('[connect error] $e');
    }
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${account.domain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._channel?.sink.close();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}
