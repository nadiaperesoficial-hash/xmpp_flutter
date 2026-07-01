import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:rxdart/rxdart.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/account/account_state.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

abstract class RosterRepo {
  Stream<List<UiBuddy>> get rosterStream;
  void addContact(UiAccount account, String jid);
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
  int _iqCounter = 0;

  @override
  Stream<List<UiBuddy>> get rosterStream => _rosterSubject.stream;

  RosterRepoImpl() {
    _accountRepo.accounts.listen(_accountsListChanged);
  }

  void _accountsListChanged(List<UiAccount> accounts) {
    for (final acc in accounts) {
      if (!_accounts.containsKey(acc)) {
        final sub = acc.accountStateStream.listen((state) {
          if (state is AccountRegistered) _requestRoster(acc);
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

  void _requestRoster(UiAccount acc) {
    acc.sendXml(
      "<iq type='get' id='roster1' xmlns='jabber:client'>"
      "<query xmlns='jabber:iq:roster'/>"
      "</iq>",
    );

    acc.channel?.stream.listen((data) {
      final xml = data.toString();

      // Roster inicial ou push de roster (novo contato adicionado)
      if (xml.contains('jabber:iq:roster')) {
        final regex = RegExp(r"jid='([^']+)'");
        final matches = regex.allMatches(xml);
        for (final match in matches) {
          final jid = match.group(1) ?? '';
          if (jid.isEmpty) continue;
          final nameRegex = RegExp("name='([^']*)'");
          final nameMatch = nameRegex.firstMatch(xml);
          final name = nameMatch?.group(1) ?? jid;
          final exists = _rosterList
              .any((b) => b.jidString == jid && b.account.id == acc.id);
          if (!exists) {
            _rosterList
                .add(UiBuddy(account: acc, jidString: jid, name: name));
            _rosterSubject.add(_rosterList);
          }
        }
      }
    });
  }

  @override
  void addContact(UiAccount account, String jid) {
    final trimmed = jid.trim();
    if (trimmed.isEmpty || !trimmed.contains('@')) return;

    _iqCounter++;
    final id = 'addcontact$_iqCounter';

    // 1. Adiciona ao roster local no servidor
    account.sendXml(
      "<iq type='set' id='$id' xmlns='jabber:client'>"
      "<query xmlns='jabber:iq:roster'>"
      "<item jid='$trimmed'/>"
      "</query>"
      "</iq>",
    );

    // 2. Envia pedido de subscription (o outro lado recebe e pode aceitar)
    account.sendXml(
      "<presence type='subscribe' to='$trimmed' xmlns='jabber:client'/>",
    );
  }

  @override
  void close() => _rosterSubject.close();
}
