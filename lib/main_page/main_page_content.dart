import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'main_page_bloc.dart';
import 'main_page_state.dart';

class RosterPage extends StatelessWidget {
  final MainPageBloc mainPageBloc;
  const RosterPage({Key? key, required this.mainPageBloc}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainPageBloc, MainPageState>(
      bloc: mainPageBloc,
      builder: (context, state) {
        if (state is MainPageRosterList) {
          if (state.activeList.isEmpty) {
            return const Center(child: Text('Nenhum contato ainda'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(1),
            itemCount: state.activeList.length,
            itemBuilder: (context, index) =>
                _buildRosterItem(state.activeList[index]),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRosterItem(UiBuddy buddy) {
    final imageData = buddy.vCard?.imageData;
    final Widget avatar = imageData == null
        ? CircleAvatar(
            radius: 25,
            child: Text(buddy.name.isNotEmpty ? buddy.name[0].toUpperCase() : '?'),
          )
        : CircleAvatar(radius: 25, backgroundImage: MemoryImage(imageData));

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
      child: Row(
        children: [
          Padding(padding: const EdgeInsets.only(left: 8), child: avatar),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(buddy.name.isNotEmpty ? buddy.name : 'Sem nome',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(buddy.jidString, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatListPage extends StatelessWidget {
  final MainPageBloc mainPageBloc;
  const ChatListPage({Key? key, required this.mainPageBloc}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MainPageBloc, MainPageState>(
      bloc: mainPageBloc,
      builder: (context, state) {
        if (state is MainPageChatList) {
          if (state.activeList.isEmpty) {
            return const Center(child: Text('Nenhuma conversa ainda'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: state.activeList.length,
            itemBuilder: (context, index) =>
                _buildChatItem(context, state.activeList[index]),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildChatItem(BuildContext context, UiChat chatItem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10, left: 5, right: 5),
      child: TextButton(
        style: TextButton.styleFrom(
          backgroundColor: Colors.grey[200],
          padding: const EdgeInsets.fromLTRB(25, 10, 25, 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {},
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              child: Text(chatItem.name.isNotEmpty ? chatItem.name[0].toUpperCase() : '?'),
            ),
            const SizedBox(width: 20),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chatItem.name.isNotEmpty ? chatItem.name : 'Sem nome'),
                  Text(chatItem.jid, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
