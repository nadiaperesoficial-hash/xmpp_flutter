// ============================================================
// account_state.dart – Definições de estado (coloque em um arquivo separado)
// ============================================================
import 'package:simple_chat/account/account_repo.dart'; // ajuste o import

abstract class AccountState {}

class AccountRegistering extends AccountState {
  final XmppAccount account;
  AccountRegistering({required this.account});
}

class AccountRegistered extends AccountState {
  final XmppAccount account;
  AccountRegistered({required this.account});
}

class AccountUnregistered extends AccountState {
  final XmppAccount account;
  final String message;
  AccountUnregistered({required this.account, required this.message});
}

// ============================================================
// account_repo.dart – Implementação completa
// ============================================================
import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

// ---------- Classes de modelo ----------
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

// ---------- Repositório ----------
abstract class AccountRepo {
  Stream<List<UiAccount>> get accounts;
  UiAccount register(XmppAccount account);
  void unregister(XmppAccount account);
  Future<bool> criarNovaContaNoServidor(XmppAccount account);
}

class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  // ---- Resolução de host/porta para servidores conhecidos ----
  _ConnectionSettings _resolveSettings(XmppAccount account) {
    String host = account.domain;
    int port = account.port;
    bool useTLS = (port == 443 || port == 5223);

    final domainLower = account.domain.toLowerCase();

    // chalec.org
    if (domainLower == 'chalec.org') {
      host = 'chalec.org';
      if (port == 0) {
        port = 5222;
        useTLS = false;
      }
    }
    // yaxim.org
    else if (domainLower == 'yaxim.org') {
      host = 'yaxim.org';
      if (port == 0) {
        port = 5222;
        useTLS = false;
      }
    }
    // 404.city (exceção existente)
    else if (domainLower == '404.city') {
      host = 'j.404.city';
      if (port == 0) {
        port = 5222;
        useTLS = false;
      }
    }
    // Outros servidores – mantém o domínio e porta informados

    return _ConnectionSettings(host, port, useTLS);
  }

  // ---- Registrar (apenas conectar) ----
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

  // ---- Criação de nova conta (com registro in‑band) ----
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
          // Tenta usar o plugin registration (se disponível)
          dynamic registrationPlugin = client.getPluginInstance('registration');
          if (registrationPlugin != null) {
            await registrationPlugin.register(
              username: account.username,
              password: account.password,
            );
            registrationDone = true;
            completer.complete(true);
            print('✅ Registro via plugin bem‑sucedido.');
            return;
          }

          // Fallback: registro manual via IQ
          await _registerManual(client, account);
          registrationDone = true;
          completer.complete(true);
          print('✅ Registro manual bem‑sucedido.');
        } catch (e) {
          registrationDone = true;
          completer.completeError(e);
          print('❌ Erro no registro: $e');
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
          print('⏱️ Timeout no registro.');
          return false;
        },
      );
    } catch (e) {
      print('❌ Falha no registro: $e');
      client.disconnect();
      return false;
    }
  }

  // ---- Registro manual (XEP‑0077) ----
  Future<void> _registerManual(Whixp client, XmppAccount account) async {
    final iq = Stanza(
      name: 'iq',
      attributes: {
        'type': 'set',
        'id': 'reg_${DateTime.now().millisecondsSinceEpoch}',
        'to': account.domain,
      },
    );

    final query = Stanza(
      name: 'query',
      attributes: {'xmlns': 'jabber:iq:register'},
    );
    query.addChild(Stanza(name: 'username', text: account.username));
    query.addChild(Stanza(name: 'password', text: account.password));

    // Alguns servidores pedem e‑mail; para chalec.org e yaxim.org não é obrigatório,
    // mas se precisar, descomente:
    // query.addChild(Stanza(name: 'email', text: 'usuario@exemplo.com'));

    iq.addChild(query);

    final response = await client.sendStanza(iq);
    if (response.attributes['type'] == 'error') {
      final error = response.findChild('error');
      if (error != null) {
        final condition = error.children.firstWhere(
          (c) => c.name == 'conflict' || c.name == 'not-allowed' || c.name == 'registration-required',
          orElse: () => Stanza(name: 'unknown'),
        );
        if (condition.name == 'conflict') {
          throw Exception('Usuário já existe.');
        } else if (condition.name == 'registration-required') {
          // Tenta extrair formulário e preencher
          await _handleRegistrationForm(client, account, response);
          return;
        } else {
          throw Exception('Erro no servidor: ${error.toXML()}');
        }
      }
    }
    // Sucesso (se não houve erro)
  }

  // ---- Tratamento de formulário (caso o servidor peça dados adicionais) ----
  Future<void> _handleRegistrationForm(Whixp client, XmppAccount account, Stanza errorResponse) async {
    final xElement = errorResponse.findChild('x', xmlns: 'jabber:x:data');
    if (xElement == null) {
      throw Exception('Servidor pediu formulário, mas não o enviou.');
    }

    final form = Stanza(
      name: 'iq',
      attributes: {
        'type': 'set',
        'id': 'reg_form_${DateTime.now().millisecondsSinceEpoch}',
        'to': account.domain,
      },
    );

    final query = Stanza(
      name: 'query',
      attributes: {'xmlns': 'jabber:iq:register'},
    );

    // Copia o <x> e preenche campos obrigatórios
    final xCopy = Stanza.fromXML(xElement.toXML());
    final fields = xCopy.findAllChildren('field');
    for (var field in fields) {
      final varName = field.attributes['var'];
      if (varName == 'email' && !account.fullJid.contains('@')) {
        field.addChild(Stanza(name: 'value', text: 'usuario@exemplo.com'));
      }
      // Se houver outro campo obrigatório, trate aqui
    }
    query.addChild(xCopy);
    form.addChild(query);

    final response = await client.sendStanza(form);
    if (response.attributes['type'] == 'error') {
      throw Exception('Falha no registro com formulário: ${response.toXML()}');
    }
  }
}

// ---- Classe auxiliar para configurações ----
class _ConnectionSettings {
  final String host;
  final int port;
  final bool useTLS;
  _ConnectionSettings(this.host, this.port, this.useTLS);
}
