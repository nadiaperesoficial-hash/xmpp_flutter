import 'package:xmpp_stone/xmpp_stone.dart';

class UiMessage {
  String? fromName;
  String? fromJid;
  int? dbId;
  String? externalId;
  String? chatExternalId;
  int? chatDbId;
  String? messageBody;
  UiMessageType type;
  final Message _xmppMessage;

  UiMessage.fromXmppMessage(this._xmppMessage)
      : type = UiMessageType.TEXT,
        messageBody = _xmppMessage.body,
        fromJid = _xmppMessage.fromJid?.fullJid;
}

enum UiMessageType { TEXT, DATE }
