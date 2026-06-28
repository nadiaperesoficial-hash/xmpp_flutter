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

    // CORREÇÃO 1: Mapeamento do host físico correto para o servidor 404.city
    String hostDeConexao = account.domain;
    if (account.domain.toLowerCase() == '404.city') {
      hostDeConexao = 'j.404.city'; 
    }

    // CORREÇÃO 2: Define se a conexão deve iniciar o socket de forma criptografada (TLS Direto)
    final bool forcarCriptografia = (account.port == 443 || account.port == 5223);

    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: hostDeConexao, 
      port: account.port,   
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(3, 15),
      
      // CORREÇÃO 3: Sintaxe oficial com letras maiúsculas exigida pelo pacote whixp
      useTLS: forcarCriptografia,

      // CORREÇÃO 4: Callback necessário para o Android aceitar certificados de servidores públicos
      onBadCertificateCallback: (certificate) => true,
    );

    uiAccount._client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    client.addEventHandler<TransportState>('state', (state) {
      if (state == null) return;
      
      print("WHIXP STATUS ATUAL DA CONEXÃO: $state");

      if (state == TransportState.connected) {
        uiAccount.accountState = AccountRegistered(account: account);
        print("Usuário autenticado com sucesso!");
      } else if (state == TransportState.disconnected) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: 'Conexão encerrada pelo servidor ou erro de credenciais.',
        );
      }
    });

    try {
      client.connect();
    } catch (e) {
      print("Erro ao tentar disparar o método connect: $e");
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: 'Erro interno ao iniciar socket de conexão.',
      );
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
