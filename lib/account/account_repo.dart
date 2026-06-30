import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
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
    _connect(uiAccount);
    return uiAccount;
  }

  void _connect(UiAccount uiAccount) {
    final account = uiAccount.account;
    bool authenticated = false;
    bool reopened = false;
    bool bound = false;
    final log = StringBuffer();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(UiAccount.wsUrl),
        protocols: ['xmpp'],
      );
      uiAccount._channel = channel;

      void send(String xml) {
        log.writeln('[tx] $xml');
        channel.sink.add(xml);
      }

      void fail(String msg) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: '$msg\n${log.toString().substring(log.length > 700 ? log.length - 700 : 0)}',
        );
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

          if (!authenticated) {
            if (xml.contains('PLAIN') ||
                xml.contains('stream:features') ||
                xml.contains('<features')) {
              final creds = base64.encode(
                utf8.encode('\x00${account.username}\x00${account.password}'),
              );
              send(
                "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
                "mechanism='PLAIN'>$creds</auth>",
              );
            } else if (xml.contains('<success')) {
              authenticated = true;
              send("<open xmlns='$_nsFraming' to='${UiAccount.serverDomain}' version='1.0'/>");
            } else if (xml.contains('<failure')) {
              fail('[auth] Usuário ou senha incorretos');
            }
            return;
          }

          // Após autenticar, aguarda o segundo <open> confirmando reabertura
          if (authenticated && !reopened) {
            if (xml.contains('<open')) {
              reopened = true;
              // Aguarda as features chegarem na próxima mensagem
            }
            return;
          }

          // Agora processa as features pós-reabertura e envia bind
          if (reopened && !bound) {
            if (xml.contains('stream:features') || xml.contains('<features')) {
              send(
                "<iq type='set' id='bind1' xmlns='jabber:client'>"
                "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
                "<resource>simple_chat</resource>"
                "</bind>"
                "</iq>",
              );
            } else if (xml.contains('id=\'bind1\'') || xml.contains('id="bind1"')) {
              if (xml.contains('type=\'result\'') || xml.contains('type="result"')) {
                bound = true;
                send("<presence xmlns='jabber:client'/>");
                uiAccount.accountState = AccountRegistered(account: account);
              } else {
                fail('[bind error] $snippet');
              }
            }
          }
        },
        onError: (e) => fail('[ws error] $e'),
        onDone: () {
          if (!bound) {
            fail('[done] auth=$authenticated reopened=$reopened bound=$bound');
          }
        },
      );

      send("<open xmlns='$_nsFraming' to='${UiAccount.serverDomain}' version='1.0'/>");
    } catch (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connect error] $e',
      );
    }
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${UiAccount.serverDomain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._channel?.sink.close();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}
