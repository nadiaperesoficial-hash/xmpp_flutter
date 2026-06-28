abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {}

class LoginFailure extends LoginState {
  final String message;
  LoginFailure({required this.message});
}

class RegisterLoading extends LoginState {}

class RegisterSuccess extends LoginState {}

class RegisterFailure extends LoginState {
  final String message;
  RegisterFailure({required this.message});
}

class LoginDataLoaded extends LoginState {
  final String username;
  final String password;
  final String domain;
  final int port;
  final bool wasExtended;
  final bool rememberMe;

  LoginDataLoaded({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
    required this.wasExtended,
    required this.rememberMe,
  });
}

class LoginExtendedChanged extends LoginState {
  final bool loginExtendValue;
  LoginExtendedChanged({required this.loginExtendValue});
}

class RememberMeChanged extends LoginState {
  final bool rememberMeValue;
  RememberMeChanged({required this.rememberMeValue});
}
