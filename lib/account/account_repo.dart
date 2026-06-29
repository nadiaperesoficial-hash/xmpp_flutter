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
  static const serverDomain = 'onyx.im';

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
    bool bound = false;
    final log = StringBuffer();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(UiAccount.wsUrl),
        protocols: ['xmpp'],
      );
      uiAccount._channel = channel;

      void send(String xml) => channel.sink.add(xml);

      void fail(String msg) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: '$msg\nLOG:\n${log.toString().substring(log.length > 500 ? log.length - 500 : 0)}',
        );
      }

      channel.stream.listen(
        (data) {
          final xml = data.toString();
          // Loga primeiros 200 chars de cada mensagem
          final snippet = xml.length > 200 ? xml.substring(0, 200) : xml;
          log.writeln('[rx] $snippet');

          if (!authenticated) {
            if (xml.contains('stream:features') || xml.contains('<features')) {
              log.writeln('[tx] sending PLAIN auth');
              final creds = base64.encode(
                utf8.encode('\x00${account.username}\x00${account.password}'),
              );
              send(
                "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
                "mechanism='PLAIN'>$creds</auth>",
              );
            } else if (xml.contains('<success')) {
              authenticated = true;
              log.writeln('[auth] success, reopening stream');
              send(
                "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
                "to='${UiAccount.serverDomain}' version='1.0'/>",
              );
            } else if (xml.contains('<failure')) {
              fail('[auth] falha SASL');
            }
          } else if (!bound) {
            if (xml.contains('stream:features') || xml.contains('<features') ||
                xml.contains('<open')) {
              log.writeln('[tx] sending bind');
              send(
                "<iq type='set' id='bind1'>"
                "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
                "<resource>simple_chat</resource>"
                "</bind>"
                "</iq>",
              );
            } else if (xml.contains('bind') && xml.contains('result')) {
              log.writeln('[tx] sending session');
              send(
                "<iq type='set' id='sess1'>"
                "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
                "</iq>",
              );
            } else if (xml.contains('sess1') || xml.contains('session')) {
              bound = true;
              log.writeln('[tx] sending presence');
              send("<presence/>");
              uiAccount.accountState = AccountRegistered(account: account);
            }
          }
        },
        onError: (e) => fail('[ws error] $e'),
        onDone: () {
          if (!bound) fail('[done] auth=$authenticated bound=$bound');
        },
      );

      log.writeln('[tx] opening stream');
      send(
        "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
        "to='${UiAccount.serverDomain}' version='1.0'/>",
      );
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
