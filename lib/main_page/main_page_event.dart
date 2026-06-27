import 'package:equatable/equatable.dart';

abstract class MainPageEvent extends Equatable {
  const MainPageEvent();
  @override
  List<Object?> get props => [];
}

class MainPageChatListTabActive extends MainPageEvent {
  const MainPageChatListTabActive();
  @override
  String toString() => 'MainPageChatListTabActive';
}

class MainPageRosterTabActive extends MainPageEvent {
  const MainPageRosterTabActive();
  @override
  String toString() => 'MainPageRosterTabActive';
}
