import 'dart:async';
import 'dart:convert';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final bool createIfMissing; // novo: se true, tenta criar conta

  XmppAccount(
    this.username,
    this.fullJid,
    this.domain,
    this.password,
    this.port, {
    this.createIfMissing = false,
  });
}

class UiAccount {
  final XmppAccount account;
  WebSocketChannel? _channel;
  final _stateSubject = BehaviorSubject<AccountState>();

  static const wsUrl = 'wss://prosody-server-production.up.railway.app/xmpp-websocket';

  Stream<AccountState> get accountStateStream => _stateSubject.stream;
  WebSocketChannel? get channel => _channel;
  String get id => '${account.username}@${account.domain}';

  set accountState(AccountState state) => _stateSubject.add(state);
  void sendXml(String xml) => _channel?.sink.add(xml);

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
    uiAccount.accountState = AccountRegistering(account: account);
    _connect(uiAccount);
    return uiAccount;
  }

  void _connect(UiAccount uiAccount) {
    final account = uiAccount.account;
    bool authenticated = false;
    bool bound = false;
    bool registered = false; // para controlar se já tentou registrar
    final log = StringBuffer();

    try {
      final channel = WebSocketChannel.connect(
        Uri.parse(UiAccount.wsUrl),
        protocols: ['xmpp'],
      );
      uiAccount._channel = channel;

      void send(String xml) {
        log.writeln('[tx] $xml');
        channel.sink.add(xml);
      }

      void fail(String msg) {
        uiAccount.accountState = AccountUnregistered(
          account: account,
          message: '$msg\nLOG:\n${log.toString().substring(log.length > 500 ? log.length - 500 : 0)}',
        );
      }

      // Função para tentar registrar a conta
      void tryRegister() {
        if (registered || account.createIfMissing == false) return;
        registered = true;
        log.writeln('[tx] requesting registration form');
        send(
          "<iq type='get' id='reg1'>"
          "<query xmlns='jabber:iq:register'/>"
          "</iq>",
        );
      }

      channel.stream.listen(
        (data) {
          final xml = data.toString();
          final snippet = xml.length > 200 ? xml.substring(0, 200) : xml;
          log.writeln('[rx] $snippet');

          if (!authenticated) {
            // Verifica se o servidor enviou features (início da autenticação)
            if (xml.contains('stream:features') || xml.contains('<features')) {
              // Se for a primeira vez e não autenticou, inicia autenticação
              log.writeln('[tx] sending PLAIN auth');
              final creds = base64.encode(
                utf8.encode('\x00${account.username}\x00${account.password}'),
              );
              send(
                "<auth xmlns='urn:ietf:params:xml:ns:xmpp-sasl' "
                "mechanism='PLAIN'>$creds</auth>",
              );
            } else if (xml.contains('<success')) {
              authenticated = true;
              log.writeln('[auth] success, reopening stream');
              send(
                "<open xmlns='urn:ietf:params:xmlns:xmpp-framing' "
                "to='${account.domain}' version='1.0'/>",
              );
            } else if (xml.contains('<failure')) {
              // Falha na autenticação – tenta registrar se permitido
              if (account.createIfMissing && !registered) {
                log.writeln('[auth] failed, trying registration...');
                tryRegister();
              } else {
                fail('[auth] falha SASL');
              }
            }
          } else if (!bound) {
            // Já autenticado, faz bind e sessão
            if (xml.contains('stream:features') || xml.contains('<features') ||
                xml.contains('<open')) {
              log.writeln('[tx] sending bind');
              send(
                "<iq type='set' id='bind1'>"
                "<bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'>"
                "<resource>simple_chat</resource>"
                "</bind>"
                "</iq>",
              );
            } else if (xml.contains('bind') && xml.contains('result')) {
              log.writeln('[tx] sending session');
              send(
                "<iq type='set' id='sess1'>"
                "<session xmlns='urn:ietf:params:xml:ns:xmpp-session'/>"
                "</iq>",
              );
            } else if (xml.contains('sess1') || xml.contains('session')) {
              bound = true;
              log.writeln('[tx] sending presence');
              send("<presence/>");
              uiAccount.accountState = AccountRegistered(account: account);
            }
          }

          // Processamento de registro (apenas durante a fase de autenticação ou após falha)
          if (!authenticated && registered) {
            // Recebeu o formulário de registro
            if (xml.contains('jabber:iq:register') && xml.contains('username')) {
              log.writeln('[tx] submitting registration');
              send(
                "<iq type='set' id='reg2'>"
                "<query xmlns='jabber:iq:register'>"
                "<username>${account.username}</username>"
                "<password>${account.password}</password>"
                "</query>"
                "</iq>",
              );
            } else if (xml.contains('iq') && xml.contains('result') && xml.contains('reg2')) {
              // Registro bem-sucedido – agora tenta autenticar novamente
              log.writeln('[register] success, retrying auth');
              registered = false; // reseta para tentar autenticar
              authenticated = false;
              // Reabre o stream para reiniciar autenticação
              send(
                "<open xmlns='urn:ietf:params:xmlns:xmpp-framing' "
                "to='${account.domain}' version='1.0'/>",
              );
            } else if (xml.contains('iq') && xml.contains('error') && xml.contains('reg2')) {
              fail('[register] error: ${xml}');
            }
          }
        },
        onError: (e) => fail('[ws error] $e'),
        onDone: () {
          if (!bound) fail('[done] auth=$authenticated bound=$bound');
        },
      );

      // Inicia o stream
      log.writeln('[tx] opening stream');
      send(
        "<open xmlns='urn:ietf:params:xmlns:xmpp-framing' "
        "to='${account.domain}' version='1.0'/>",
      );
    } catch (e) {
      uiAccount.accountState = AccountUnregistered(
        account: account,
        message: '[connect error] $e',
      );
    }
  }

  @override
  void unregister(XmppAccount account) {
    final id = '${account.username}@${account.domain}';
    final idx = _accountsList.indexWhere((a) => a.id == id);
    if (idx != -1) {
      _accountsList[idx]._channel?.sink.close();
      _accountsList.removeAt(idx);
    }
    _accountSubject.add(_accountsList);
  }
}
