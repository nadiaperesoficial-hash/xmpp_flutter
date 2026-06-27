import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/repo/db/db_chat.dart';
import 'package:simple_chat/repo/ui_message.dart';

class UiChat {
  int? dbId;
  String _name = '';
  UiAccount account;
  String jid = '';
  UiChatStatus status = UiChatStatus.ACTIVE;
  UiChatType type = UiChatType.SINGLE;
  DateTime created = DateTime.now();
  final List<UiMessage> _messages = [];
  final _messagesSubject = BehaviorSubject<List<UiMessage>>();

  bool get isEmpty => jid.isEmpty;

  Stream<List<UiMessage>> get uiMessages => _messagesSubject.stream;

  @override
  bool operator ==(other) =>
      other is UiChat && jid == other.jid && account.id == other.account.id;

  @override
  int get hashCode => Object.hash(jid, account.id);

  UiChat.fromJid(this.jid, this.account) {
    _name = jid;
    created = DateTime.now();
  }

  UiChat.fromDbChat(DbChat dbChat, this.account) {
    jid = dbChat.jid;
    dbId = dbChat.uuid;
    _name = dbChat.name;
    status = _statusFromInt(dbChat.status);
    type = _typeFromInt(dbChat.type);
  }

  UiChat.empty() : account = UiAccount(XmppAccount('', '', '', '', 0));

  void addMessage(String body, {required bool fromMe}) {
    _messages.add(UiMessage(
      messageBody: body,
      fromMe: fromMe,
      timestamp: DateTime.now(),
    ));
    _messagesSubject.add(_messages);
  }

  Future<bool> sendMessage(String body) async {
    addMessage(body, fromMe: true);
    return true;
  }

  UiChatStatus _statusFromInt(int s) {
    switch (s) {
      case 1: return UiChatStatus.INACTIVE;
      case 2: return UiChatStatus.ARCHIVED;
      default: return UiChatStatus.ACTIVE;
    }
  }

  UiChatType _typeFromInt(int t) =>
      t == 1 ? UiChatType.MUC : UiChatType.SINGLE;

  String get name => _name.isNotEmpty ? _name : jid;

  DbChat get getDbChat => DbChat(
        name: name,
        account_id: account.id,
        jid: jid,
        since: created.millisecondsSinceEpoch,
        type: type.index,
        status: status.index,
      );
}

enum UiChatType { SINGLE, MUC }
enum UiChatStatus { ACTIVE, INACTIVE, ARCHIVED }
