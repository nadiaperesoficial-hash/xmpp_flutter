import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account); // Mantido o retorno sincronizado original
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

    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: account.domain,
      port: account.port,
      // CORRIGIDO: Passando string vazia no lugar de null para satisfazer o linter e limpar cache travado
      internalDatabasePath: '', 
      reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    // Evento nativo de conexão estabilizada para o whixp disparar a presença
    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;
      
      if (state == TransportState.connected) {
        client.sendPresence();
        uiAccount.accountState = AccountRegistered(account: account);
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'Falha na conexão física.',
        );
      }
    });

    // Captura erro específico de falha de credenciais (SASL) do servidor
    client.addEventHandler<String>('saslFailure', (_) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: 'Falha na autenticação',
      );
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
}
