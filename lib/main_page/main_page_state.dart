import 'package:equatable/equatable.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/roster/roster_repo.dart';

abstract class MainPageState extends Equatable {
  const MainPageState();
  @override
  List<Object?> get props => [];
}

class MainPageRosterList extends MainPageState {
  final List<UiBuddy> activeList;
  const MainPageRosterList({required this.activeList});
  @override
  List<Object?> get props => [activeList];
}

class MainPageChatList extends MainPageState {
  final List<UiChat> activeList;
  const MainPageChatList({required this.activeList});
  @override
  List<Object?> get props => [activeList];
}
