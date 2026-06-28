import 'package:get_it/get_it.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/repo/chats_repo.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'package:simple_chat/settings/settings.dart';

GetIt sl = GetIt.instance;

void setupServiceLocator() {
  sl.registerSingleton<Settings>(SettingsImpl());
  sl.registerSingleton<AccountRepo>(AccountRepoImpl());
  sl.registerSingleton<ChatsRepo>(ChatsRepoImpl());
  sl.registerSingleton<RosterRepo>(RosterRepoImpl());
}
