// account_repo.dart
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart'; // onde estão as classes de estado
import 'package:whixp/whixp.dart';

// ----- Classes de modelo (mantidas como estavam) -----
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

// ----- Repositório abstrato (mantido) -----
abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
  Future<bool> criarNovaContaNoServidor(XmppAccount account);
}

// ----- Implementação corrigida -----
class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  // --- Auxiliar para resolver host/porta para servidores específicos ---
  _ConnectionSettings _resolveSettings(XmppAccount account) {
    String host = account.domain;
    int port = account.port;
    bool useTLS = (port == 443 || port == 5223);

    final domainLower = account.domain.toLowerCase();
    if (domainLower == '404.city') {
      host = 'j.404.city';
      if (port == 0) port = 5222;
      useTLS = false;
    } else if (domainLower == 'chalec.org' || domainLower == 'yaxim.org') {
      // Esses servidores aceitam registro in‑band sem CAPTCHA.
      // Mantemos o domínio literal e porta padrão (5222) se não especificada.
      if (port == 0) port = 5222;
      useTLS = false;
    }
    // Outros servidores usam os valores fornecidos.

    return _ConnectionSettings(host, port, useTLS);
  }

  @override
  UiAccount register(XmppAccount account) {
    final uiAccount = UiAccount(account);
    _accountsList.removeWhere((a) => a == uiAccount);
    _accountsList.add(uiAccount);
    _accountSubject.add(_accountsList);

    final settings = _resolveSettings(account);
    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: settings.host,
      port: settings.port,
      internalDatabasePath: 'whixp_${account.username}',
      reconnectionPolicy: RandomBackoffReconnectionPolicy(3, 15),
      useTLS: settings.useTLS,
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

  // ----- MÉTODO DE CRIAÇÃO DE CONTA CORRIGIDO -----
  @override
  Future<bool> criarNovaContaNoServidor(XmppAccount account) async {
    final settings = _resolveSettings(account);
    final client = Whixp(
      jabberID: '${account.username}@${account.domain}/simple_chat',
      password: account.password,
      host: settings.host,
      port: settings.port,
      internalDatabasePath: 'whixp_reg_${account.username}',
      useTLS: settings.useTLS,
      onBadCertificateCallback: (certificate) => true,
    );

    final completer = Completer<bool>();
    bool registrationDone = false;

    // Aguarda a conexão
    client.addEventHandler<TransportState>('state', (state) async {
      if (state == TransportState.connected && !registrationDone) {
        try {
          // Tenta registrar via plugin ou manual
          final success = await _registerAccount(client, account);
          registrationDone = true;
          completer.complete(success);
        } catch (e) {
          registrationDone = true;
          completer.completeError(e);
        }
      }
    });

    client.connect();

    // Timeout de 30 segundos
    try {
      return await completer.future.timeout(
        Duration(seconds: 30),
        onTimeout: () {
          client.disconnect();
          return false;
        },
      );
    } catch (e) {
      print('Falha no registro: $e');
      client.disconnect();
      return false;
    }
  }

  // ---- Tenta registrar (plugin ou manual) ----
  Future<bool> _registerAccount(Whixp client, XmppAccount account) async {
    // 1. Tenta usar o plugin 'registration' se disponível
    try {
      // Nota: se o whixp não tiver getPluginInstance, isso lançará exceção.
      final plugin = client.getPluginInstance('registration');
      if (plugin != null) {
        await plugin.register(username: account.username, password: account.password);
        return true;
      }
    } catch (_) {
      // Plugin não disponível, segue para manual
    }

    // 2. Fallback: registro manual via IQ (XEP-0077)
    return _registerManual(client, account);
  }

  // ---- Registro manual usando IQ ----
  Future<bool> _registerManual(Whixp client, XmppAccount account) async {
    // Cria o IQ de registro
    final iq = Stanza(
      'iq',
      attributes: {
        'type': 'set',
        'id': 'reg_${DateTime.now().millisecondsSinceEpoch}',
        'to': account.domain,
      },
    );

    // Query com xmlns jabber:iq:register
    final query = Stanza(
      'query',
      attributes: {'xmlns': 'jabber:iq:register'},
    );
    query.addChild(Stanza('username', text: account.username));
    query.addChild(Stanza('password', text: account.password));
    // Se o servidor pedir e-mail (ex: alguns), descomente:
    // query.addChild(Stanza('email', text: 'usuario@exemplo.com'));

    iq.addChild(query);

    // Envia e aguarda resposta
    final response = await client.sendStanza(iq);

    // Verifica se houve erro
    if (response.attributes['type'] == 'error') {
      final error = response.findChild('error');
      if (error != null) {
        final condition = error.children.firstWhere(
          (c) => c.name == 'conflict' || c.name == 'not-allowed' || c.name == 'registration-required',
          orElse: () => Stanza('unknown'),
        );
        if (condition.name == 'conflict') {
          throw Exception('Usuário já existe.');
        } else if (condition.name == 'registration-required') {
          // Para chalec.org e yaxim.org isso não deve acontecer, mas se ocorrer,
          // podemos tentar extrair e preencher formulário.
          throw Exception('Servidor requer dados adicionais (formulário).');
        } else {
          throw Exception('Erro no servidor: ${error.toXML()}');
        }
      } else {
        throw Exception('Erro desconhecido no registro.');
      }
    }

    // Sucesso
    return true;
  }
}

// ----- Classe auxiliar para configurações -----
class _ConnectionSettings {
  final String host;
  final int port;
  final bool useTLS;
  _ConnectionSettings(this.host, this.port, this.useTLS);
}
