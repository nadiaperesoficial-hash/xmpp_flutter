import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/login/login_events.dart';
import 'package:simple_chat/login/login_states.dart';
import 'package:simple_chat/registration/xmpp_registrar.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'package:simple_chat/settings/settings.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AccountBloc accountBloc;
  final Settings _settings = sl.get<Settings>();
  bool _extended = false;
  bool _rememberMe = false;
  StreamSubscription? _accountSub;

  LoginBloc({required this.accountBloc}) : super(const LoginInitial()) {
    on<LoginButtonPressed>(_onLoginPressed);
    on<RegisterButtonPressed>(_onRegisterPressed);
    on<ExtendPressed>(_onExtendPressed);
    on<RememberMePressed>(_onRememberMePressed);
    on<LoginDataLoadedEvent>(_onLoginDataLoaded);
    on<LoginDataShownEvent>(_onLoginDataShown);
    on<LoginFailureEvent>(_onLoginFailure);

    _initData();
    _accountSub = accountBloc.stream.listen((state) {
      if (state is AccountUnregistered) {
        add(LoginFailureEvent(message: state.message));
      }
    });
  }

  void _onLoginPressed(LoginButtonPressed event, Emitter<LoginState> emit) {
    String username, password, domain;
    int port;
    if (_extended) {
      username = event.username;
      password = event.password;
      domain = event.domain;
      port = event.port;
    } else {
      final parts = event.username.split('@');
      username = parts[0];
      domain = parts.length > 1 ? parts[1] : '';
      password = event.password;
      port = _settings.getDefaultPort();
    }
    if (_rememberMe) {
      _settings.setString(Settings.username, username);
      _settings.setString(Settings.domain, domain);
      _settings.setString(Settings.password, password);
      _settings.setInt(Settings.port, port);
    }
    accountBloc.add(Login(username: username, password: password, domain: domain, port: port));
    emit(const LoginInitial());
  }

  Future<void> _onRegisterPressed(RegisterButtonPressed event, Emitter<LoginState> emit) async {
    emit(const RegisterLoading());
    try {
      await XmppRegistrar(
        domain: event.domain,
        host: event.domain,
        port: event.port,
        username: event.username,
        password: event.password,
      ).register();
      emit(const RegisterSuccess());
      accountBloc.add(Login(username: event.username, password: event.password, domain: event.domain, port: event.port));
    } catch (e) {
      emit(RegisterFailure(message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onExtendPressed(ExtendPressed event, Emitter<LoginState> emit) {
    _extended = !_extended;
    _settings.setBool(Settings.wasExtended, _extended);
    emit(LoginExtendedChanged(loginExtendValue: _extended));
  }

  void _onRememberMePressed(RememberMePressed event, Emitter<LoginState> emit) {
    _rememberMe = event.rememberMeValue;
    _settings.setBool(Settings.rememberMe, _rememberMe);
    if (!_rememberMe) accountBloc.add(const ForgetMe());
    emit(RememberMeChanged(rememberMeValue: _rememberMe));
  }

  void _onLoginDataLoaded(LoginDataLoadedEvent event, Emitter<LoginState> emit) {
    _rememberMe = event.rememberMe;
    _extended = event.wasExtended;
    emit(LoginDataLoaded(username: event.username, password: event.password, domain: event.domain, port: event.port, wasExtended: event.wasExtended, rememberMe: event.rememberMe));
  }

  void _onLoginDataShown(LoginDataShownEvent event, Emitter<LoginState> emit) {
    emit(const LoginInitial());
  }

  void _onLoginFailure(LoginFailureEvent event, Emitter<LoginState> emit) {
    emit(LoginFailure(message: event.message));
  }

  void _initData() {
    _settings.isInitialized().then((_) {
      if (_settings.getBool(Settings.rememberMe) == true) {
        final u = _settings.getString(Settings.username) ?? '';
        final p = _settings.getString(Settings.password) ?? '';
        final d = _settings.getString(Settings.domain) ?? '';
        var port = _settings.getInt(Settings.port) ?? _settings.getDefaultPort();
        final wasExtended = _settings.getBool(Settings.wasExtended) ?? false;
        _extended = wasExtended;
        add(LoginDataLoadedEvent(username: u, password: p, domain: d, port: port, wasExtended: wasExtended, rememberMe: true));
      } else {
        add(LoginDataLoadedEvent(username: '', password: '', domain: '', port: _settings.getDefaultPort(), wasExtended: _settings.getBool(Settings.wasExtended) ?? false, rememberMe: false));
      }
    });
  }

  @override
  Future<void> close() {
    _accountSub?.cancel();
    return super.close();
  }
}
