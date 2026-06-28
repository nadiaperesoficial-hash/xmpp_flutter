abstract class LoginEvent {}

class LoginButtonPressed extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;

  LoginButtonPressed({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
  });
}

class RegisterButtonPressed extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;

  RegisterButtonPressed({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
  });
}

class ExtendPressed extends LoginEvent {}

class RememberMePressed extends LoginEvent {
  final bool rememberMeValue;
  RememberMePressed({required this.rememberMeValue});
}

class LoginDataLoadedEvent extends LoginEvent {
  final String username;
  final String password;
  final String domain;
  final int port;
  final bool wasExtended;
  final bool rememberMe;

  LoginDataLoadedEvent({
    required this.username,
    required this.password,
    required this.domain,
    required this.port,
    required this.wasExtended,
    required this.rememberMe,
  });
}

class LoginDataShownEvent extends LoginEvent {}

class LoginFailureEvent extends LoginEvent {
  final String message;
  LoginFailureEvent({required this.message});
}

class LoginSuccessEvent extends LoginEvent {}
