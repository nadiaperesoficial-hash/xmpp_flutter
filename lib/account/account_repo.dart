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
  final _messageController = StreamController<Map<String, String>>.broadcast();

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  Stream<Map<String, String>> get messageStream => _messageController.stream;
  String get id => '${account.username}@$_domain';

  set accountState(AccountState state) => _stateSubject.add(state);

  void sendMessage(String to, String body) {
    _channel?.sink.add(
      "<message to='$to' type='chat'><body>$body</body></message>",
    );
  }

  void disconnect() {
    _channel?.sink.add("<close xmlns='urn:ietf:params:xml:ns:xmpp-websocket'/>");
    _channel?.sink.close();
  }

  UiAccount(this.account);
}

class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  static const _wsUrl = 'wss://laylaprs-meuchatxmpp.hf.space/xmpp-websocket';
  static const _domain = 'onyx.im';

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    uiAccount.accountState = AccountRegistering(account: account);
    _connect(uiAccount, account);
    return uiAccount;
  }

  void _connect(UiAccount uiAccount, XmppAccount account) async {
    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(_wsUrl),
        protocols: ['xmpp'],
      );
      await channel.ready;
      uiAccount._channel = channel;

      final buffer = StringBuffer();
      String stage = 'open';

      channel.stream.listen(
        (data) {
          buffer.write(data.toString());
          final xml = buffer.toString();

          if (stage == 'open' && xml.contains('<open')) {
            stage = 'features';
            buffer.clear();
          } else if (stage == 'features' && xml.contains('stream:features')) {
            stage = 'auth';
            buffer.clear();
            final creds = '\x00${account.username}\x00${account.password}';
            final b64 = base64.encode(utf8.encode(creds));
            channel.sink.add(
              "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' mechanism='PLAIN'>$b64</auth>",
            );
          } else if (stage == 'auth' && xml.contains('<success')) {
            stage = 'reopen';
            buffer.clear();
            channel.sink.add(
              "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
              "to='$_domain' version='1.0'/>",
            );
          } else if (stage == 'auth' && xml.contains('<failure')) {
            uiAccount.accountState = AccountUnregistered(
              account: account,
              message: '[authFailed] Usuário ou senha incorretos',
            );
          } else if (stage == 'reopen' && xml.contains('stream:features')) {
            stage = 'bind';
            buffer.clear();
            channel.sink.add(
              "<iq type='set' id='bind1'>"
              "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
              "<resource>simple_chat</resource>"
              "</bind></iq>",
            );
          } else if (stage == 'bind' && xml.contains("id='bind1'") && xml.contains('type="result"')) {
            stage = 'session';
            buffer.clear();
            channel.sink.add(
              "<iq type='set' id='sess1'>"
              "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
              "</iq>",
            );
          } else if (stage == 'session') {
            stage = 'connected';
            buffer.clear();
            channel.sink.add("<presence/>");
            uiAccount.accountState = AccountRegistered(account: account);
          } else if (stage == 'connected' && xml.contains('<message')) {
            // Mensagem recebida
            buffer.clear();
          }
        },
        onError: (e) {
          uiAccount.accountState = AccountUnregistered(
            account: account,
            message: '[wsError] ${e.toString()}',
          );
        },
        onDone: () {
          uiAccount.accountState = AccountUnregistered(
            account: account,
            message: '[wsDone] Conexão encerrada',
          );
        },
      );

      channel.sink.add(
        "<open xmlns='urn:ietf:params:xml:ns:xmpp-websocket' "
        "to='$_domain' version='1.0'/>",
      );
    } catch (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connectError] ${e.toString()}',
      );
    }
  }

  @override
  void unregister(XmppAccount account) {
    final idx = _accountsList.indexWhere(
        (a) => a.account.username == account.username);
    if (idx != -1) {
      _accountsList[idx].disconnect();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}
