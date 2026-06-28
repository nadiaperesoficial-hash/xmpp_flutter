import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  Future<UiAccount?> register(XmppAccount account);
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

    final loginCompleter = Completer<bool>();

    // Ajuste físico de host para desvios conhecidos (como o 404.city se usado)
    String hostDeConexao = account.domain;
    if (account.domain.toLowerCase() == '404.city') {
      hostDeConexao = 'j.404.city';
    }

    // CONFIGURAÇÃO REESTRUTURADA PARA SE ADAPTAR AOS SERVIDORES COMUNITÁRIOS:
    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: hostDeConexao,
      port: account.port,
      
      // Passar nulo remove o cache em banco local para este login, impedindo travamento por dados corrompidos
      internalDatabasePath: null, 
      
      reconnectionPolicy: null, 
      useTLS: (account.port == 443 || account.port == 5223),
      onBadCertificateCallback: (certificate) => true,
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    // Captura o evento de estado da conexão
    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;

      if (state == TransportState.connected) {
        uiAccount.accountState = AccountRegistered(account: account);
        if (!loginCompleter.isCompleted) loginCompleter.complete(true);
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'Falha na conexão física com o servidor.',
        );
        if (!loginCompleter.isCompleted) loginCompleter.complete(false);
      }
    });

    // Captura erros explícitos de autenticação de credenciais rejeitadas pelo servidor
    client.addEventHandler<String>('saslFailure', (condition) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: 'Usuário ou senha incorretos.',
      );
      if (!loginCompleter.isCompleted) loginCompleter.complete(false);
    });

    try {
      client.connect();
      
      // Aguarda a negociação de pacotes por até 12 segundos antes de liberar a interface gráfica
      final sucessoNoLogin = await loginCompleter.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => false,
      );

      if (!sucessoNoLogin) {
        _accountsList.remove(uiAccount);
        _accountSubject.add(_accountsList);
        return null; 
      }
    } catch (e) {
      _accountsList.remove(uiAccount);
      _accountSubject.add(_accountsList);
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
