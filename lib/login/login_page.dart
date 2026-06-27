import 'package:flutter/material.dart';
import 'package:simple_chat/account/account_bloc.dart';
import 'package:simple_chat/login/login_bloc.dart';
import 'package:simple_chat/login/login_form.dart';

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: LoginForm(loginBloc: _loginBloc),
        ),
      ),
    );
  }
}
