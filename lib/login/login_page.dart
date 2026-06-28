import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/login/login_bloc.dart';
import 'package:simple_chat/login/login_form.dart';
import 'package:simple_chat/login/login_state.dart';

class LoginPage extends StatefulWidget {
  static const String tag = 'login';
  final AccountBloc accountBloc;

  const LoginPage(this.accountBloc, {Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late LoginBloc _loginBloc;

  @override
  void initState() {
    super.initState();
    _loginBloc = LoginBloc(accountBloc: widget.accountBloc);
  }

  @override
  void dispose() {
    _loginBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccountBloc, AccountState>(
      bloc: widget.accountBloc,
      listener: (context, state) {
        if (state is AccountRegistering) {
          // Mostra loading
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conectando...'),
              duration: Duration(seconds: 30),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        if (state is AccountUnregistered && state.message != null && state.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: LoginForm(loginBloc: _loginBloc),
          ),
        ),
      ),
    );
  }
}
