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
    return BlocProvider<AccountBloc>(
      create: (_) => accountBloc,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            if (state is AccountRegistered) {
              return MainPage(accountBloc);
            }
            return LoginPage(accountBloc);
          },
        ),
      ),
    );
  }
}
