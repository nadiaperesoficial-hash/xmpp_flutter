import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();
  @override
  List<Object?> get props => [];
}

class LoginButtonPressed extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;
  const LoginButtonPressed({required this.username, required this.password, required this.domain, required this.port});
  @override
  List<Object?> get props => [username, password, domain, port];
}

class RegisterButtonPressed extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;
  const RegisterButtonPressed({required this.username, required this.password, required this.domain, required this.port});
  @override
  List<Object?> get props => [username, password, domain, port];
}

class ExtendPressed extends LoginEvent { const ExtendPressed(); }

class RememberMePressed extends LoginEvent {
  final bool rememberMeValue;
  const RememberMePressed({required this.rememberMeValue});
  @override
  List<Object?> get props => [rememberMeValue];
}

class LoginDataLoadedEvent extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;
  final bool wasExtended;
  final bool rememberMe;
  const LoginDataLoadedEvent({required this.username, required this.password, required this.domain, required this.port, required this.wasExtended, required this.rememberMe});
  @override
  List<Object?> get props => [username, password, domain, port, wasExtended, rememberMe];
}

class LoginDataShownEvent extends LoginEvent { const LoginDataShownEvent(); }

class LoginFailureEvent extends LoginEvent {
  final String? message;
  const LoginFailureEvent({this.message});
  @override
  List<Object?> get props => [message];
}
