import 'package:equatable/equatable.dart';
import 'package:simple_chat/account/account_repo.dart';

abstract class AccountEvent extends Equatable {
  const AccountEvent();
  @override
  List<Object?> get props => [];
}

class AppStarted extends AccountEvent {
  const AppStarted();
  @override
  String toString() => 'AppStarted';
}

class Login extends AccountEvent {
  final String username;
  final String password;
  final String domain;
  final int port;

  const Login({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
  });

  @override
  List<Object?> get props => [username, password, domain, port];
  @override
  String toString() => 'Login { username: $username }';
}

class AccountRegisteredEvent extends AccountEvent {
  final XmppAccount? account;
  const AccountRegisteredEvent({this.account});
  @override
  List<Object?> get props => [account];
  @override
  String toString() => 'AccountRegisteredEvent';
}

class AccountRegistrationFailedEvent extends AccountEvent {
  final XmppAccount? account;
  final String? message;
  const AccountRegistrationFailedEvent({this.account, this.message});
  @override
  List<Object?> get props => [account, message];
  @override
  String toString() => 'AccountRegistrationFailedEvent';
}

class Logout extends AccountEvent {
  const Logout();
  @override
  String toString() => 'Logout';
}

class ForgetMe extends AccountEvent {
  const ForgetMe();
  @override
  String toString() => 'ForgetMe';
}
