import 'dart:io';
import 'package:flutter/material.dart';
import 'package:simple_chat/account/account.dart';
import 'main_page_bloc.dart';
import 'main_page_content.dart';
import 'main_page_event.dart';

class MainPage extends StatefulWidget {
  static const String TAG = 'main';
  final AccountBloc accountBloc;
  const MainPage(this.accountBloc, {Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MainPageBloc _mainPageBloc = MainPageBloc();

  final List<_Choice> _choices = const [
    _Choice(title: 'Settings', icon: Icons.settings),
    _Choice(title: 'Log out', icon: Icons.exit_to_app),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: 2);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openExitDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        contentPadding: EdgeInsets.zero,
        children: [
          Container(
            color: Colors.orangeAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            height: 100,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app, size: 30, color: Colors.white),
                SizedBox(height: 8),
                Text('Sair do app', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Tem certeza?', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: const Row(children: [Icon(Icons.cancel), SizedBox(width: 10), Text('CANCELAR', style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: const Row(children: [Icon(Icons.check_circle), SizedBox(width: 10), Text('SIM', style: TextStyle(fontWeight: FontWeight.bold))]),
          ),
        ],
      ),
    );
    if (result == 1) exit(0);
  }

  void _handleTabSelection() {
    if (_tabController.index == 1) {
      _mainPageBloc.add(MainPageChatListTabActive());
    } else {
      _mainPageBloc.add(MainPageRosterTabActive());
    }
  }

  void _onMenuPress(_Choice choice) {
    if (choice.title == 'Log out') widget.accountBloc.add(Logout());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Roster'), Tab(text: 'Chat')]),
        title: const Text('Simple Chat', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          PopupMenuButton<_Choice>(
            onSelected: _onMenuPress,
            itemBuilder: (_) => _choices.map((c) => PopupMenuItem<_Choice>(
              value: c,
              child: Row(children: [Icon(c.icon, color: Colors.black87), const SizedBox(width: 10), Text(c.title)]),
            )).toList(),
          ),
        ],
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (_) => _openExitDialog(),
        child: TabBarView(
          controller: _tabController,
          children: [
            RosterPage(mainPageBloc: _mainPageBloc),
            ChatListPage(mainPageBloc: _mainPageBloc),
          ],
        ),
      ),
    );
  }
}

class _Choice {
  final String title;
  final IconData icon;
  const _Choice({required this.title, required this.icon});
}
