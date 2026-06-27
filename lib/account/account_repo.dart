import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart';

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
  XmppConnection? _connection;
  final _stateSubject = BehaviorSubject<AccountState>();

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);

  @override
  bool operator ==(other) =>
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
  final Map<String, XmppConnection> _connections = {};

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    final params = {
      'user_jid': '${account.username}@${account.domain}',
      'password': account.password,
      'host': account.domain,
      'port': account.port.toString(),
      'requireSSLConnection': true,
      'autoDeliveryReceipt': true,
      'useStreamManagement': false,
      'automaticReconnection': true,
    };

    final connection = XmppConnection(params);
    _connections[uiAccount.id] = connection;
    uiAccount.accountState = AccountRegistering(account: account);

    connection.start((error) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: error.toString(),
      );
    }).then((_) async {
      await connection.login();
      uiAccount.accountState = AccountRegistered(account: account);
    }).catchError((e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: e.toString(),
      );
    });

    return uiAccount;
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${account.domain}';
    _connections[id]?.logout();
    _connections.remove(id);
    _accountsList.removeWhere((a) => a.id == id);
    _accountSubject.add(_accountsList);
  }
}
