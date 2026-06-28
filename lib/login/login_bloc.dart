import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/login/login_event.dart';
import 'package:simple_chat/login/login_state.dart';
import 'package:simple_chat/registration/xmpp_registrar.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'package:simple_chat/settings/settings.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final AccountBloc accountBloc;
  final Settings _settings = sl.get<Settings>();
  bool _extended = false;
  bool _rememberMe = false;
  StreamSubscription? _accountSub;

  // Dados salvos separadamente
  String _savedUsername = '';
  String _savedDomain = '';
  String _savedPassword = '';
  int _savedPort = 5222;

  LoginBloc({required this.accountBloc}) : super(const LoginInitial()) {
    on<LoginButtonPressed>(_onLoginPressed);
    on<RegisterButtonPressed>(_onRegisterPressed);
    on<ExtendPressed>(_onExtendPressed);
    on<RememberMePressed>(_onRememberMePressed);
    on<LoginDataLoadedEvent>(_onLoginDataLoaded);
    on<LoginDataShownEvent>(_onLoginDataShown);
    on<LoginFailureEvent>(_onLoginFailure);
    on<LoginSuccessEvent>(_onLoginSuccess);

    // Escuta o AccountBloc para mapear estados
    _accountSub = accountBloc.stream.listen((accountState) {
      if (accountState is AccountRegistered) {
        // Login bem-sucedido
        add(LoginSuccessEvent());
      } else if (accountState is AccountUnregistered) {
        // Login falhou
        add(LoginFailureEvent(message: accountState.message ?? 'Falha na conexão'));
      }
    });

    _initData();
  }

  @override
  Future<void> close() {
    _accountSub?.cancel();
    return super.close();
  }

  // ===== Handlers =====

  void _onLoginPressed(LoginButtonPressed event, Emitter<LoginState> emit) {
    String username, password, domain;
    int port;

    if (_extended) {
      // Modo avançado: campos separados
      username = event.username.trim();
      password = event.password;
      domain = event.domain.trim();
      port = event.port;
    } else {
      // Modo básico: campo único usuario@dominio
      final input = event.username.trim();
      if (input.contains('@')) {
        final parts = input.split('@');
        username = parts[0];
        domain = parts[1];
      } else {
        emit(LoginFailure(message: 'Use o formato usuário@servidor.com ou ative o modo Avançado'));
        return;
      }
      password = event.password;
      port = _settings.getDefaultPort();
    }

    if (username.isEmpty || domain.isEmpty) {
      emit(LoginFailure(message: 'Preencha usuário e servidor'));
      return;
    }

    // Salva se "lembrar" estiver ativo
    if (_rememberMe) {
      _settings.setString(Settings.username, username);
      _settings.setString(Settings.domain, domain);
      _settings.setString(Settings.password, password);
      _settings.setInt(Settings.port, port);
      _settings.setBool(Settings.wasExtended, _extended);
    }

    // Emite loading antes de tentar conectar
    emit(LoginLoading());

    // Dispara o login no AccountBloc
    accountBloc.add(Login(
      username: username,
      password: password,
      domain: domain,
      port: port,
    ));
  }

  Future<void> _onRegisterPressed(
      RegisterButtonPressed event, Emitter<LoginState> emit) async {
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
      // Após registrar, faz login automaticamente
      accountBloc.add(Login(
        username: event.username,
        password: event.password,
        domain: event.domain,
        port: event.port,
      ));
    } catch (e) {
      emit(RegisterFailure(
          message: e.toString().replaceAll('Exception: ', '')));
    }
  }

  void _onExtendPressed(ExtendPressed event, Emitter<LoginState> emit) {
    _extended = !_extended;
    _settings.setBool(Settings.wasExtended, _extended);
    _loadSavedData();
    emit(LoginExtendedChanged(loginExtendValue: _extended));
  }

  void _onRememberMePressed(
      RememberMePressed event, Emitter<LoginState> emit) {
    _rememberMe = event.rememberMeValue;
    _settings.setBool(Settings.rememberMe, _rememberMe);
    if (!_rememberMe) {
      accountBloc.add(const ForgetMe());
      _settings.remove(Settings.username);
      _settings.remove(Settings.domain);
      _settings.remove(Settings.password);
      _settings.remove(Settings.port);
      _savedUsername = '';
      _savedDomain = '';
      _savedPassword = '';
      _savedPort = 5222;
    }
    emit(RememberMeChanged(rememberMeValue: _rememberMe));
  }

  void _onLoginDataLoaded(
      LoginDataLoadedEvent event, Emitter<LoginState> emit) {
    _rememberMe = event.rememberMe;
    _extended = event.wasExtended;
    _savedUsername = event.username;
    _savedDomain = event.domain;
    _savedPassword = event.password;
    _savedPort = event.port;

    String displayUser;
    if (_extended) {
      displayUser = _savedUsername;
    } else {
      displayUser = _savedUsername.isNotEmpty && _savedDomain.isNotEmpty
          ? '$_savedUsername@$_savedDomain'
          : '';
    }

    emit(LoginDataLoaded(
      username: displayUser,
      password: _savedPassword,
      domain: _savedDomain,
      port: _savedPort,
      wasExtended: _extended,
      rememberMe: _rememberMe,
    ));
  }

  void _onLoginDataShown(
      LoginDataShownEvent event, Emitter<LoginState> emit) {
    emit(const LoginInitial());
  }

  void _onLoginFailure(LoginFailureEvent event, Emitter<LoginState> emit) {
    emit(LoginFailure(message: event.message));
  }

  void _onLoginSuccess(LoginSuccessEvent event, Emitter<LoginState> emit) {
    emit(LoginSuccess());
  }

  // ===== Helpers =====

  void _loadSavedData() {
    final remember = _settings.getBool(Settings.rememberMe) ?? false;
    _rememberMe = remember;
    if (remember) {
      _savedUsername = _settings.getString(Settings.username) ?? '';
      _savedDomain = _settings.getString(Settings.domain) ?? '';
      _savedPassword = _settings.getString(Settings.password) ?? '';
      _savedPort = _settings.getInt(Settings.port) ?? _settings.getDefaultPort();
    } else {
      _savedUsername = '';
      _savedDomain = '';
      _savedPassword = '';
      _savedPort = _settings.getDefaultPort();
    }
    _extended = _settings.getBool(Settings.wasExtended) ?? false;

    String displayUser;
    if (_extended) {
      displayUser = _savedUsername;
    } else {
      displayUser = _savedUsername.isNotEmpty && _savedDomain.isNotEmpty
          ? '$_savedUsername@$_savedDomain'
          : '';
    }

    add(LoginDataLoadedEvent(
      username: displayUser,
      password: _savedPassword,
      domain: _savedDomain,
      port: _savedPort,
      wasExtended: _extended,
      rememberMe: _rememberMe,
    ));
  }

  void _initData() {
    _loadSavedData();
  }
}
