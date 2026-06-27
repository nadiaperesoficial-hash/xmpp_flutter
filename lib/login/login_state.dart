import 'package:equatable/equatable.dart';

abstract class LoginState extends Equatable {
  const LoginState();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginExtendedChanged extends LoginState {
  final bool loginExtendValue;
  const LoginExtendedChanged({required this.loginExtendValue});
  @override
  List<Object?> get props => [loginExtendValue];
}

class RememberMeChanged extends LoginState {
  final bool rememberMeValue;
  const RememberMeChanged({required this.rememberMeValue});
  @override
  List<Object?> get props => [rememberMeValue];
}

class LoginDataLoaded extends LoginState {
  final String username;
  final String password;
  final String domain;
  final int port;
  final bool wasExtended;
  final bool rememberMe;

  const LoginDataLoaded({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
    required this.wasExtended,
    required this.rememberMe,
  });

  @override
  List<Object?> get props =>
      [username, password, domain, port, wasExtended, rememberMe];
}

class LoginFailure extends LoginState {
  final String? message;
  const LoginFailure({this.message});
  @override
  List<Object?> get props => [message];
}

class RegisterLoading extends LoginState {
  const RegisterLoading();
}

class RegisterSuccess extends LoginState {
  const RegisterSuccess();
}

class RegisterFailure extends LoginState {
  final String message;
  const RegisterFailure({required this.message});
  @override
  List<Object?> get props => [message];
}
