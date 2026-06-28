import 'dart:async';
// import 'dart:typed_data';  // ← remova esta linha
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

abstract class RosterRepo {
  Stream<List<UiBuddy>> get rosterStream;
  void close();
}

class VCardData {
  final Uint8List? imageData;
  VCardData({this.imageData});
}

class UiBuddy {
  final UiAccount account;
  final String jidString;
  final String name;
  VCardData? vCard;

  UiBuddy({required this.account, required this.jidString, required this.name});
}

class RosterRepoImpl implements RosterRepo {
  final _accountRepo = sl.get<AccountRepo>();
  final List<UiBuddy> _rosterList = [];
  final _rosterSubject = BehaviorSubject<List<UiBuddy>>();
  final Map<UiAccount, StreamSubscription> _accounts = {};

  @override
  Stream<List<UiBuddy>> get rosterStream => _rosterSubject.stream;

  RosterRepoImpl() {
    _accountRepo.accounts.listen(_accountsListChanged);
  }

  void _accountsListChanged(List<UiAccount> accounts) {
    for (final acc in accounts) {
      if (!_accounts.containsKey(acc)) {
        final sub = acc.accountStateStream.listen((state) {
          if (state is AccountRegistered) _loadRoster(acc);
        });
        _accounts[acc] = sub;
      }
    }
    final toRemove =
        _accounts.keys.where((a) => !accounts.contains(a)).toList();
    for (final acc in toRemove) {
      _accounts[acc]?.cancel();
      _accounts.remove(acc);
      _rosterList.removeWhere((b) => b.account.id == acc.id);
      _rosterSubject.add(_rosterList);
    }
  }

  void _loadRoster(UiAccount acc) {
    final client = acc.client;
    if (client == null) return;

    client.addEventHandler<Map<String, dynamic>?>('rosterReceived', (roster) {
      if (roster == null) return;
      // 🔽 CORREÇÃO: use roster! para garantir não nulo
      roster!.forEach((jid, info) {
        final infoMap = info as Map<String, dynamic>?;
        final name = (infoMap?['name'] as String?)?.isNotEmpty == true
            ? infoMap!['name'] as String
            : jid;
        final exists = _rosterList
            .any((b) => b.jidString == jid && b.account.id == acc.id);
        if (!exists) {
          _rosterList.add(UiBuddy(account: acc, jidString: jid, name: name));
        }
      });
      _rosterSubject.add(_rosterList);
    });
  }

  @override
  void close() => _rosterSubject.close();
}
