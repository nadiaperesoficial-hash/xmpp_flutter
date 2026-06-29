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
    final buffer = StringBuffer();
    bool authenticated = false;
    bool bound = false;

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(UiAccount.wsUrl),
        protocols: ['xmpp'],
      );
      uiAccount._channel = channel;

      void send(String xml) => channel.sink.add(xml);

      void processXml(String xml) {
        // Fase 1: servidor confirmou abertura do stream
        if (xml.contains('<open') && !authenticated) {
          // Verifica se já veio features junto
          if (xml.contains('stream:features') || xml.contains('<features')) {
            _sendAuth(account, send);
          }
          // Se não veio features ainda, aguarda próxima mensagem
          return;
        }

        // Fase 2: features em mensagem separada
        if (!authenticated &&
            (xml.contains('stream:features') || xml.contains('<features')) &&
            !xml.contains('<open')) {
          _sendAuth(account, send);
          return;
        }

        // Fase 3: resultado da autenticação
        if (!authenticated && xml.contains('<success')) {
          authenticated = true;
          buffer.clear();
          // Reabre stream
          send(
            "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
            "to='${UiAccount.serverDomain}' version='1.0'/>",
          );
          return;
        }

        if (!authenticated && xml.contains('<failure')) {
          uiAccount.accountState = AccountUnregistered(
            account: account,
            message: '[auth] Usuário ou senha incorretos',
          );
          return;
        }

        // Fase 4: segundo <open> após reautenticação
        if (authenticated && !bound && xml.contains('<open')) {
          send(
            "<iq type='set' id='bind1'>"
            "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
            "<resource>simple_chat</resource>"
            "</bind>"
            "</iq>",
          );
          return;
        }

        // Features após reautenticação — envia bind
        if (authenticated && !bound &&
            (xml.contains('stream:features') || xml.contains('<features'))) {
          send(
            "<iq type='set' id='bind1'>"
            "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
            "<resource>simple_chat</resource>"
            "</bind>"
            "</iq>",
          );
          return;
        }

        // Fase 5: bind confirmado
        if (authenticated && !bound &&
            (xml.contains('id=\'bind1\'') || xml.contains('id="bind1"')) &&
            xml.contains('type=\'result\'') || xml.contains('type="result"') && xml.contains('bind')) {
          bound = true;
          send(
            "<iq type='set' id='sess1'>"
            "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
            "</iq>",
          );
          return;
        }

        // Fase 6: session ou conectado
        if (bound && (xml.contains('id=\'sess1\'') || xml.contains('id="sess1"') ||
            xml.contains('type=\'result\'') || xml.contains('type="result"'))) {
          send("<presence/>");
          uiAccount.accountState = AccountRegistered(account: account);
        }
      }

      channel.stream.listen(
        (data) {
          buffer.write(data.toString());
          final xml = buffer.toString();
          buffer.clear();
          processXml(xml);
        },
        onError: (e) {
          uiAccount.accountState = AccountUnregistered(
            account: account,
            message: '[ws error] ${e.toString()}',
          );
        },
        onDone: () {
          if (!bound) {
            uiAccount.accountState = AccountUnregistered(
              account: account,
              message: '[ws done] auth=$authenticated bound=$bound',
            );
          }
        },
      );

      // Abre stream
      send(
        "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
        "to='${UiAccount.serverDomain}' version='1.0'/>",
      );
    } catch (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connect error] ${e.toString()}',
      );
    }
  }

  void _sendAuth(XmppAccount account, void Function(String) send) {
    final creds = base64.encode(
      utf8.encode('\x00${account.username}\x00${account.password}'),
    );
    send(
      "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
      "mechanism='PLAIN'>$creds</auth>",
    );
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
