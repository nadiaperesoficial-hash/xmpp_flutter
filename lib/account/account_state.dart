import 'package:equatable/equatable.dart';
import 'package:simple_chat/account/account_repo.dart';

abstract class AccountState extends Equatable {
  const AccountState();
  @override
  List<Object?> get props => [];
}

class AccountRegistered extends AccountState {
  final XmppAccount? account;
  const AccountRegistered({required this.account});
  @override
  List<Object?> get props => [account];
  @override
  String toString() => 'AccountRegistered';
}

class AccountRegistering extends AccountState {
  final XmppAccount? account;
  const AccountRegistering({required this.account});
  @override
  List<Object?> get props => [account];
  @override
  String toString() => 'AccountRegistering';
}

class AccountUnregistered extends AccountState {
  final XmppAccount? account;
  final String? message;
  const AccountUnregistered({required this.account, required this.message});
  @override
  List<Object?> get props => [account, message];
  @override
  String toString() => 'AccountUnregistered';
}

class AccountUninitialized extends AccountState {
  final XmppAccount? account;
  const AccountUninitialized({required this.account});
  @override
  List<Object?> get props => [account];
  @override
  String toString() => 'AccountUninitialized';
}
