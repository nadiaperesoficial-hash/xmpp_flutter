import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
  Future<bool> criarNovaContaNoServidor(XmppAccount account);
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
  Whixp? _client;
  final _stateSubject = BehaviorSubject<AccountState>();

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  Whixp? get client => _client;
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

    String hostDeConexao = account.domain;
    if (account.domain.toLowerCase() == '404.city') {
      hostDeConexao = 'j.404.city';
    }

    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: hostDeConexao,
      port: account.port,
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(3, 15),
      useTLS: (account.port == 443 || account.port == 5223),
      onBadCertificateCallback: (certificate) => true,
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;
      if (state == TransportState.connected) {
        uiAccount.accountState = AccountRegistered(account: account);
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'Conexão encerrada',
        );
      }
    });

    client.connect();
    return uiAccount;
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${account.domain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._client?.disconnect();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }

  @override
  Future<bool> criarNovaContaNoServidor(XmppAccount account) async {
    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: account.domain,
      port: account.port,
      internalDatabasePath: 'whixp_reg_${account.username}',
      useTLS: (account.port == 443 || account.port == 5223),
      onBadCertificateCallback: (certificate) => true,
    );

    try {
      // CORRIGIDO: Acessa o mapa público 'plugins' direto pelo nome da extensão
      final dynamic registrationPlugin = client.plugins['registration'];
      
      if (registrationPlugin != null) {
        await registrationPlugin.register(
          username: account.username,
          password: account.password,
        );
        print("Usuário registrado com sucesso no servidor de chat público!");
        return true;
      }
      return false;
    } catch (e) {
      print("Falha na requisição de registro XMPP local: $e");
      return false;
    }
  }
}
