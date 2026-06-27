import 'dart:async';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'package:xmpp_plugin/xmpp_plugin.dart';

abstract class RosterRepo {
  Stream<List<UiBuddy>> get rosterStream;
  void close();
}

class UiBuddy {
  final UiAccount account;
  final String jidString;
  final String name;
  VCardData? vCard;

  String get fullJid => jidString;

  UiBuddy({
    required this.account,
    required this.jidString,
    required this.name,
  });
}

class VCardData {
  final List<int>? imageData;
  VCardData({this.imageData});
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
          if (state is AccountRegistered) {
            _loadRoster(acc);
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
      _rosterList.removeWhere((b) => b.account.id == acc.id);
      _rosterSubject.add(_rosterList);
    }
  }

  Future<void> _loadRoster(UiAccount acc) async {
    final contacts = await XmppPlugin.instance.getRoster();
    for (final contact in contacts) {
      final exists = _rosterList.any((b) =>
          b.jidString == contact.jid && b.account.id == acc.id);
      if (!exists) {
        final buddy = UiBuddy(
          account: acc,
          jidString: contact.jid ?? '',
          name: contact.name ?? contact.jid ?? '',
        );
        _rosterList.add(buddy);
      }
    }
    _rosterSubject.add(_rosterList);
  }

  @override
  void close() => _rosterSubject.close();
}
