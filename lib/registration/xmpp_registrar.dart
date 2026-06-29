import 'dart:async';
import 'package:simple_chat/account/account_repo.dart';
import 'package:whixp/whixp.dart';

class XmppRegistrar {
  final String username;
  final String password;

  XmppRegistrar({
    required String domain,
    required String host,
    required int port,
    required this.username,
    required this.password,
  });

  Future<void> register() async {
    final completer = Completer<void>();

    // Inicializa uma instância temporária do Whixp dedicada ao registro
    final client = Whixp(
      jabberID: '$username@${UiAccount.serverDomain}/register_payload',
      password: password,
      host: UiAccount.wsUrl, // Utiliza a URL wss:// direta no host do Whixp
      port: 443,
      useTLS: true,
      logger: Log(enableWarning: true, enableError: true),
    );

    // Evento disparado quando o túnel WebSocket com o Hugging Face abre e valida os headers
    client.addEventHandler<dynamic>('connected', (_) async {
      try {
        // Obtém o plugin In-Band Registration nativo do pacote Whixp
        final registrationPlugin = client.getPlugin<InBandRegistration>('register');
        
        // Envia de forma estruturada a requisição XML de criação de conta
        await registrationPlugin.registerAccount(username, password);
        
        if (!completer.isCompleted) completer.complete();
        client.disconnect(); // Fecha a conexão de registro após o sucesso
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(Exception(_parseError(e.toString())));
        }
        client.disconnect();
      }
    });

    // Captura falhas de conexão de rede de forma proativa antes do timeout
    client.addEventHandler<dynamic>('connectionFailed', (e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Falha ao conectar à infraestrutura da nuvem: $e'));
      }
    });

    // Intercepta erros genéricos disparados pela biblioteca
    client.addEventHandler<dynamic>('error', (e) {
      if (!completer.isCompleted) {
        completer.completeError(Exception(_parseError(e.toString())));
      }
    });

    // Dispara o início assíncrono do túnel de conexão
    client.connect();

    try {
      // Estabelece a barreira de tempo padrão de 30 segundos
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Timeout ao registrar conta na nuvem'),
      );
    } finally {
      // Garante que o cliente temporário seja liberado da memória
      client.disconnect();
    }
  }

  String _parseError(String errorLog) {
    final logLower = errorLog.toLowerCase();
    if (logLower.contains('conflict')) return 'Usuário já existe';
    if (logLower.contains('not-acceptable')) return 'Dados inválidos';
    if (logLower.contains('forbidden')) return 'Registro não permitido';
    if (logLower.contains('not-allowed')) return 'Registro desabilitado pelo servidor';
    return 'Erro ao criar conta no servidor onyx.im';
  }
}
