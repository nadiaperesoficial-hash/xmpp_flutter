import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/repo/db/db_chat.dart';
import 'package:simple_chat/repo/ui_message.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

class UiChat {
  int? dbId;
  String _name = '';
  UiAccount account;
  late Jid jid;
  UiChatStatus status = UiChatStatus.ACTIVE;
  UiChatType type = UiChatType.SINGLE;
  DateTime created = DateTime.now();
  final List<UiMessage> _messages = [];
  final _messagesSubject = BehaviorSubject<List<UiMessage>>();
  Chat? _xmppChat;
  StreamSubscription<Message>? _sub;

  bool get isEmpty => jid.fullJid.isEmpty;

  Chat? get xmppChat => _xmppChat;

  set xmppChat(Chat? value) {
    _sub?.cancel();
    _xmppChat = value;
    if (value != null) _subscribeToMessageStream();
  }

  @override
  bool operator ==(other) =>
      other is UiChat && jid == other.jid && account == other.account;

  @override
  int get hashCode => Object.hash(jid, account);

  Future<bool> sendMessage(String message) async {
    if (_xmppChat == null) return false;
    _xmppChat!.sendMessage(message);
    return true;
  }

  Stream<List<UiMessage>> get uiMessages => _messagesSubject.stream;

  UiChat.fromXmppChat(this._xmppChat, this.account) {
    jid = _xmppChat!.jid;
    _name = jid.fullJid;
    created = DateTime.now();
    _subscribeToMessageStream();
  }

  UiChat.fromDbChat(DbChat dbChat, this.account) {
    jid = Jid.fromFullJid(dbChat.jid);
    dbId = dbChat.uuid;
    _name = dbChat.name;
    status = _statusFromInt(dbChat.status);
    type = _typeFromInt(dbChat.type);
  }

  UiChat.empty() : account = UiAccount(XmppAccount('', '', '', '', 0)) {
    jid = Jid.fromFullJid('');
  }

  void _subscribeToMessageStream() {
    _sub = _xmppChat!.newMessageStream.listen((xmppMessage) {
      _messages.add(UiMessage.fromXmppMessage(xmppMessage));
      _messagesSubject.add(_messages);
    });
  }

  UiChatStatus _statusFromInt(int s) {
    switch (s) {
      case 1: return UiChatStatus.INACTIVE;
      case 2: return UiChatStatus.ARCHIVED;
      default: return UiChatStatus.ACTIVE;
    }
  }

  UiChatType _typeFromInt(int t) {
    return t == 1 ? UiChatType.MUC : UiChatType.SINGLE;
  }

  String get name => _name.isNotEmpty ? _name : jid.userAtDomain;

  DbChat get getDbChat => DbChat(
        name: name,
        account_id: account.id,
        jid: jid.fullJid,
        since: created.millisecondsSinceEpoch,
        type: type.index,
        status: status.index,
      );
}

enum UiChatType { SINGLE, MUC }
enum UiChatStatus { ACTIVE, INACTIVE, ARCHIVED }
