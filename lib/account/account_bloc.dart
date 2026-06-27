import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/account/account_repo.dart';
import 'package:simple_chat/service_locator/service_locator.dart';
import 'package:simple_chat/settings/settings.dart';
import 'package:xmpp_stone/xmpp_stone.dart' as xmpp;

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final settings = sl.get<Settings>();
  final accountRepo = sl.get<AccountRepo>();

  AccountBloc() : super(AccountUninitialized(account: null)) {
    on<AppStarted>(_onAppStarted);
    on<Login>(_onLogin);
    on<Logout>(_onLogout);
    on<ForgetMe>(_onForgetMe);
    on<AccountRegisteredEvent>(_onAccountRegistered);
    on<AccountRegistrationFailedEvent>(_onAccountRegistrationFailed);
  }

  Future<void> _onAppStarted(
      AppStarted event, Emitter<AccountState> emit) async {
    await settings.isInitialized();
    final shouldStart = settings.getBool(Settings.isAccountSaved) &&
        settings.getBool(Settings.wasLoggedIn);
    if (shouldStart) {
      final account = settings.getAccountData();
      if (account == null) {
        emit(AccountUnregistered(account: null, message: null));
      } else {
        emit(AccountRegistering(account: account));
        _registerAccount(account);
      }
    } else {
      emit(AccountUnregistered(account: null, message: null));
    }
  }

  void _onLogin(Login event, Emitter<AccountState> emit) {
    final account = xmpp.XmppAccount(
      event.username,
      event.username,
      event.domain,
      event.password,
      event.port,
    );
    emit(AccountRegistering(account: account));
    _registerAccount(account);
  }

  void _onLogout(Logout event, Emitter<AccountState> emit) {
    final account = settings.getAccountData();
    settings.setBool(Settings.wasLoggedIn, false);
    if (account != null) accountRepo.unregister(account);
    emit(AccountUnregistered(account: account, message: ''));
  }

  void _onForgetMe(ForgetMe event, Emitter<AccountState> emit) {
    settings.forgetAccount();
  }

  void _onAccountRegistered(
      AccountRegisteredEvent event, Emitter<AccountState> emit) {
    settings.setBool(Settings.wasLoggedIn, true);
    emit(AccountRegistered(account: event.account));
  }

  void _onAccountRegistrationFailed(
      AccountRegistrationFailedEvent event, Emitter<AccountState> emit) {
    emit(AccountUnregistered(account: event.account, message: event.message));
  }

  void _registerAccount(xmpp.XmppAccount account) {
    settings.setAccountData(account);
    accountRepo.register(account).accountStateStream.listen((state) {
      if (state is AccountUnregistered) {
        add(AccountRegistrationFailedEvent(
            account: account, message: state.message));
      } else if (state is AccountRegistered) {
        add(AccountRegisteredEvent(account: account));
      }
    });
  }
}
