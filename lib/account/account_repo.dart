import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

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
  Whixp? client;
  final _stateSubject = BehaviorSubject<AccountState>();

  static const wsUrl = 'wss://laylaprs-meuchatxmpp.hf.space/xmpp-websocket';
  static const serverDomain = 'onyx.im';

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

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    final client = Whixp(
      jabberID: '${account.username}@${UiAccount.serverDomain}/simple_chat',
      password: account.password,
      host: UiAccount.serverDomain,
      wsEndpoint: UiAccount.wsUrl,
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
      logger: Log(enableWarning: true, enableError: true),
    );

    uiAccount.client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    client.addEventHandler<dynamic>('streamNegotiated', (_) {
      client.sendPresence();
      uiAccount.accountState = AccountRegistered(account: account);
    });

    client.addEventHandler<dynamic>('disconnected', (_) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[disconnected] Conexão encerrada',
      );
    });

    client.addEventHandler<dynamic>('failed', (_) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[failed] Falha na autenticação',
      );
    });

    client.addEventHandler<dynamic>('connectionFailed', (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connectionFailed] ${e?.toString() ?? "sem detalhes"}',
      );
    });

    client.addEventHandler<dynamic>('error', (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[error] ${e?.toString() ?? "erro desconhecido"}',
      );
    });

    client.connect();
    return uiAccount;
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${UiAccount.serverDomain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx].client?.disconnect();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}
