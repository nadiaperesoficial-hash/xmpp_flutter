import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:whixp/whixp.dart';

// As classes XmppAccount, UiAccount e AccountState permanecem iguais.
// Mantenha-as como estão.

class AccountRepoImpl implements AccountRepo {
  final _accountSubject = BehaviorSubject<List<UiAccount>>();
  final List<UiAccount> _accountsList = [];

  @override
  Stream<List<UiAccount>> get accounts => _accountSubject.stream;

  // --- Método auxiliar para obter host e porta corretos ---
  _ConnectionSettings _resolveSettings(XmppAccount account) {
    String host = account.domain;
    int port = account.port;
    bool useTLS = (port == 443 || port == 5223);

    // Exceções conhecidas (ex.: 404.city)
    if (account.domain.toLowerCase() == '404.city') {
      host = 'j.404.city';
      // Se não especificou porta, use 5222 (padrão) ou 5223 com TLS
      if (port == 0) {
        port = 5222;
        useTLS = false;
      }
    }
    // Adicione outras exceções conforme necessário

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

  // --- MÉTODO DE REGISTRO CORRIGIDO ---
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

    // Variáveis para controlar o fluxo
    Completer<bool> completer = Completer<bool>();
    bool registrationDone = false;

    // Escuta eventos de estado para saber quando conectar
    client.addEventHandler<TransportState>('state', (state) async {
      if (state == TransportState.connected && !registrationDone) {
        // Conectado, agora tenta registrar
        try {
          // Tenta usar o plugin 'registration' (se disponível)
          dynamic registrationPlugin = client.getPluginInstance('registration');
          if (registrationPlugin != null) {
            await registrationPlugin.register(
              username: account.username,
              password: account.password,
            );
            registrationDone = true;
            completer.complete(true);
            print('Registro via plugin bem‑sucedido.');
            return;
          }

          // Fallback: registro manual via IQ
          await _registerManual(client, account);
          registrationDone = true;
          completer.complete(true);
          print('Registro manual bem‑sucedido.');
        } catch (e) {
          registrationDone = true;
          completer.completeError(e);
          print('Erro no registro: $e');
        }
      }
    });

    // Inicia a conexão
    client.connect();

    // Aguarda a conclusão ou timeout (30 segundos)
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

  // --- Registro manual via IQ (XEP-0077) ---
  Future<void> _registerManual(Whixp client, XmppAccount account) async {
    // Cria um IQ de registro
    final iq = Stanza(
      name: 'iq',
      attributes: {
        'type': 'set',
        'id': 'reg_${DateTime.now().millisecondsSinceEpoch}',
        'to': account.domain,
      },
    );

    // Elemento <query xmlns='jabber:iq:register'>
    final query = Stanza(
      name: 'query',
      attributes: {'xmlns': 'jabber:iq:register'},
    );
    query.addChild(Stanza(name: 'username', text: account.username));
    query.addChild(Stanza(name: 'password', text: account.password));

    // Se o servidor exigir e‑mail, descomente a linha abaixo
    // query.addChild(Stanza(name: 'email', text: 'email@exemplo.com'));

    iq.addChild(query);

    // Envia e aguarda resposta
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
          // Pode ser necessário preencher um formulário.
          // Tenta extrair o formulário e enviar de novo.
          await _handleRegistrationForm(client, account, response);
          return;
        } else {
          throw Exception('Erro no servidor: ${error.toXML()}');
        }
      }
    }
    // Sucesso
  }

  // --- Tratamento de formulário (ex.: CAPTCHA ou dados adicionais) ---
  Future<void> _handleRegistrationForm(Whixp client, XmppAccount account, Stanza errorResponse) async {
    // Procura por <x xmlns='jabber:x:data'> no erro
    final xElement = errorResponse.findChild('x', xmlns: 'jabber:x:data');
    if (xElement == null) {
      throw Exception('Servidor pediu formulário, mas não o enviou.');
    }

    // Cria uma nova IQ com o formulário preenchido
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

    // Copia o <x> e preenche os campos obrigatórios
    final xCopy = Stanza.fromXML(xElement.toXML()); // deep copy
    // Preenche campos com valores padrão (ex.: e‑mail, captcha)
    // Para simplificar, assumimos que só pede username/password/email
    // Você pode adaptar para ler os campos e preencher.
    // Exemplo: se tiver campo 'email', adicione valor.
    final fields = xCopy.findAllChildren('field');
    for (var field in fields) {
      final varName = field.attributes['var'];
      if (varName == 'email' && account.fullJid.contains('@')) {
        // Preenche com um e‑mail fictício (se não tiver)
        field.addChild(Stanza(name: 'value', text: 'user@example.com'));
      }
      // Outros campos podem ser preenchidos aqui
    }

    query.addChild(xCopy);
    form.addChild(query);

    final response = await client.sendStanza(form);
    if (response.attributes['type'] == 'error') {
      throw Exception('Falha no registro com formulário: ${response.toXML()}');
    }
  }

  // --- Classe auxiliar para configurações ---
}

class _ConnectionSettings {
  final String host;
  final int port;
  final bool useTLS;
  _ConnectionSettings(this.host, this.port, this.useTLS);
}
