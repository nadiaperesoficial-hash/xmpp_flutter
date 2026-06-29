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
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _loginBloc = LoginBloc(accountBloc: widget.accountBloc);

    widget.accountBloc.stream.listen((state) {
      if (!mounted) return;
      setState(() {
        final ts = DateTime.now().toIso8601String().substring(11, 19);
        _debugLog = '[$ts] ${state.toString()}\n$_debugLog';
      });
    });
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Conectando...'),
              duration: Duration(seconds: 30),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        }
        if (state is AccountUnregistered &&
            state.message != null &&
            state.message!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: LoginForm(loginBloc: _loginBloc),
                ),
              ),
              // Debug log visível
              if (_debugLog.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  color: Colors.black87,
                  padding: const EdgeInsets.all(8),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _debugLog,
                      style: const TextStyle(
                        color: Colors.greenBright,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
