import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:simple_chat/repo/db/db.dart';
import 'package:simple_chat/repo/db/db_chat.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'package:whixp/whixp.dart';

abstract class ChatsRepo {
  Stream<List<UiChat>> get chatsStream;
}

class ChatsRepoImpl implements ChatsRepo {
  final _accountRepo = sl.get<AccountRepo>();
  final List<UiChat> _chats = [];
  final _chatsSubject = BehaviorSubject<List<UiChat>>();
  final Map<UiAccount, StreamSubscription> _accounts = {};
  final _db = DatabaseHelper();

  @override
  Stream<List<UiChat>> get chatsStream => _chatsSubject.stream;

  ChatsRepoImpl() {
    _db.initDatabase();
    _accountRepo.accounts.listen(_accountListChanged);
  }

  void _accountListChanged(List<UiAccount> accounts) {
    for (final acc in accounts) {
      if (!_accounts.containsKey(acc)) {
        final sub = acc.accountStateStream.listen((state) {
          if (state is AccountRegistered) {
            _loadChatsFromDb(acc);
            _listenMessages(acc);
          }
        });
        _accounts[acc] = sub;
      }
    }
    final toRemove =
        _accounts.keys.where((a) => !accounts.contains(a)).toList();
    for (final acc in toRemove) {
      _accounts[acc]?.cancel();
      _accounts.remove(acc);
    }
  }

  void _listenMessages(UiAccount acc) {
    acc.client?.addEventHandler<Message>('message', (message) {
      if (message == null) return;
      final fromJid = message.from?.toString() ?? '';
      final body = message.body ?? '';
      if (fromJid.isEmpty || body.isEmpty) return;

      var chat = _chats.firstWhere(
        (c) => c.jid == fromJid && c.account.id == acc.id,
        orElse: () {
          final newChat = UiChat.fromJid(fromJid, acc);
          _db.insert(newChat.getDbChat)
              .then((inserted) => newChat.dbId = inserted.uuid);
          _chats.add(newChat);
          return newChat;
        },
      );
      chat.addMessage(body, fromMe: false);
      _chatsSubject.add(_chats);
    });
  }

  Future<void> _loadChatsFromDb(UiAccount account) async {
    final rows = await _db.getAllDbChatsForAccountId(account.id);
    for (final row in rows) {
      final dbChat = DbChat.fromMap(row);
      final exists = _chats
          .any((c) => c.jid == dbChat.jid && c.account.id == account.id);
      if (!exists) {
        _chats.add(UiChat.fromDbChat(dbChat, account));
      }
    }
    _chatsSubject.add(_chats);
  }
}
