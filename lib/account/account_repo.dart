import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  Future<UiAccount?> register(XmppAccount account); // Mudado para Future para aguardar o login real
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
  Future<UiAccount?> register(XmppAccount account) async {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    // O Completer impede o código de avançar e quebrar a interface antes do login concluir
    final loginCompleter = Completer<bool>();

    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: account.domain,
      port: account.port,
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: null, // Evita metralhadora de reconexões que reinicia a tela
      useTLS: (account.port == 443 || account.port == 5223),
      onBadCertificateCallback: (certificate) => true,
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;

      if (state == TransportState.connected) {
        uiAccount.accountState = AccountRegistered(account: account);
        if (!loginCompleter.isCompleted) loginCompleter.complete(true);
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'Falha na autenticação do servidor.',
        );
        if (!loginCompleter.isCompleted) loginCompleter.complete(false);
      }
    });

    try {
      client.connect();
      
      // Bloqueia a execução por até 10 segundos aguardando a resposta real do socket XMPP
      final sucessoNoLogin = await loginCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => false,
      );

      if (!sucessoNoLogin) {
        // Se o login falhou, limpamos a instância e retornamos nulo para a UI saber o que houve
        _accountsList.remove(uiAccount);
        _accountSubject.add(_accountsList);
        return null; 
      }
    } catch (e) {
      return null;
    }

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
