/// Configuração de servidores XMPP suportados pelo app.
///
/// Cada servidor define o domínio e a lista de portas WebSocket a tentar,
/// nessa ordem (443 primeiro, 5280 como fallback).
class XmppServerOption {
  final String name;
  final String domain;
  final List<int> wsPorts;
  final String wsPath;

  const XmppServerOption({
    required this.name,
    required this.domain,
    this.wsPorts = const [443, 5280],
    this.wsPath = '/xmpp-websocket',
  });

  /// Gera as URLs candidatas de WebSocket, na ordem de prioridade das portas.
  List<String> buildWsUrls() {
    return wsPorts.map((port) {
      if (port == 443) {
        return 'wss://$domain$wsPath';
      }
      return 'wss://$domain:$port$wsPath';
    }).toList();
  }
}

/// Servidor próprio (Railway) sempre como primeira opção.
const kPrimaryServer = XmppServerOption(
  name: 'Meu servidor (Railway)',
  domain: 'prosody-server-production.up.railway.app',
  wsPorts: [443, 5280],
);

/// Lista de servidores públicos conhecidos (baseado na lista do Yaxim),
/// usados como alternativa caso o usuário escolha "servidor público".
const kPublicServers = <XmppServerOption>[
  XmppServerOption(name: '0nl1ne.at', domain: '0nl1ne.at'),
  XmppServerOption(name: 'blah.im', domain: 'blah.im'),
  XmppServerOption(name: 'boese-ban.de', domain: 'boese-ban.de'),
  XmppServerOption(name: 'brauchen.info', domain: 'brauchen.info'),
];

/// Todos os servidores conhecidos (primário + públicos), nessa ordem.
const kAllServers = <XmppServerOption>[kPrimaryServer, ...kPublicServers];

/// Procura um servidor conhecido pelo domínio informado.
/// Se não encontrar, cria uma opção genérica com fallback padrão 443->5280.
XmppServerOption resolveServer(String domain) {
  for (final s in kAllServers) {
    if (s.domain == domain) return s;
  }
  return XmppServerOption(name: domain, domain: domain);
}

/// Retorna a lista de URLs WebSocket candidatas para um domínio,
/// já respeitando o fallback de portas (443 -> 5280).
List<String> candidateWsUrls(String domain) {
  return resolveServer(domain).buildWsUrls();
}
