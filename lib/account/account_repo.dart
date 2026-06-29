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

  // CORREÇÃO: Atualizado para o novo endereço WebSocket ativo na Railway
  static const wsUrl = 'wss://prosody-production.up.railway.app/xmpp-websocket';
  
  // CORREÇÃO: Atualizado para o domínio padrão 'localhost' exigido pela imagem Docker do Prosody
  static const serverDomain = 'localhost';

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);

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

    // Inicializa o cliente Whixp direcionando as credenciais para o host da Railway
    final client = Whixp(
      jabberID: '${account.username}@${UiAccount.serverDomain}/simple_chat',
      password: account.password,
      host: UiAccount.wsUrl, // Injeta o endpoint wss:// da Railway diretamente no transporte
      port: 443,
      useTLS: true,
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
      logger: Log(enableWarning: true, enableError: true),
    );

    uiAccount.client = client;
    uiAccount.accountState = AccountRegistering(account: account);

    // Evento correto disparado após o handshake estável do WebSocket na Railway
    client.addEventHandler<dynamic>('connected', (_) {
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

    // Inicia a negociação assíncrona baseada nos parâmetros do construtor
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
