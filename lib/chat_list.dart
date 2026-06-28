import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:simple_chat/const.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'package:simple_chat/service_locator/service_locator.dart';

class ChatList extends StatefulWidget {
  static const String tag = 'chat-list';
  const ChatList({Key? key}) : super(key: key);

  @override
  State<ChatList> createState() => ChatListState();
}

class ChatListState extends State<ChatList> {
  final _rosterRepo = sl.get<RosterRepo>();

  Future<void> _openDialog() async {
    final result = await showDialog<int>(
      context: context,
      builder: (_) => SimpleDialog(
        contentPadding: EdgeInsets.zero,
        children: [
          Container(
            color: themeColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            height: 100,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.exit_to_app, size: 30, color: Colors.white),
                SizedBox(height: 8),
                Text('Exit app', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('Are you sure?', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 0),
            child: Row(children: [Icon(Icons.cancel, color: primaryColor), const SizedBox(width: 10), Text('CANCEL', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))]),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 1),
            child: Row(children: [Icon(Icons.check_circle, color: primaryColor), const SizedBox(width: 10), Text('YES', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))]),
          ),
        ],
      ),
    );
    if (result == 1) exit(0);
  }

  Widget _buildItem(UiBuddy buddy) {
    final imageData = buddy.vCard?.imageData;
    final Widget avatar = imageData == null
        ? CircleAvatar(radius: 25, child: Text(buddy.name.isNotEmpty ? buddy.name[0] : '?'))
        : CircleAvatar(radius: 25, backgroundImage: MemoryImage(imageData));

    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: greyColor2,
          padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {},
        child: Row(
          children: [
            Material(borderRadius: BorderRadius.circular(5), clipBehavior: Clip.hardEdge, child: avatar),
            const SizedBox(width: 20),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Name: ${buddy.name.isNotEmpty ? buddy.name : 'No Info'}', style: TextStyle(color: primaryColor)),
                  const SizedBox(height: 4),
                  Text('Jid: ${buddy.jidString}', style: TextStyle(color: primaryColor, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MAIN', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: PopScope(
        canPop: false,
        onPopInvoked: (_) => _openDialog(),
        child: StreamBuilder<List<UiBuddy>>(
          initialData: const [],
          stream: _rosterRepo.rosterStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(themeColor)));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: snapshot.data!.length,
              itemBuilder: (_, index) => _buildItem(snapshot.data![index]),
            );
          },
        ),
      ),
    );
  }
}
