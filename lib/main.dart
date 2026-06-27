import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_chat/account/account.dart';
import 'package:simple_chat/login/login_page.dart';
import 'package:simple_chat/main_page/main_page_widget.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _AppState();
}

class _AppState extends State<MyApp> {
  late AccountBloc accountBloc;
  final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey(debugLabel: 'Main Navigator');

  @override
  void initState() {
    super.initState();
    accountBloc = AccountBloc();
    accountBloc.add(AppStarted());
  }

  @override
  void dispose() {
    accountBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AccountBloc, AccountState>(
      bloc: accountBloc,
      listener: (context, state) {
        if (state is AccountUninitialized || state is AccountUnregistered) {
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(LoginPage.tag, (_) => false);
        } else if (state is AccountRegistered) {
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(MainPage.TAG, (_) => false);
        } else if (state is AccountRegistering) {
          navigatorKey.currentState
              ?.pushNamedAndRemoveUntil(LoginPage.tag, (_) => false);
        }
      },
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        initialRoute: LoginPage.tag,
        routes: {
          LoginPage.tag: (_) => LoginPage(accountBloc),
          MainPage.TAG: (_) => MainPage(accountBloc),
        },
      ),
    );
  }
}
