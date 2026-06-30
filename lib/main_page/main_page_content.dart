import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/roster/roster_repo.dart';
import 'main_page_bloc.dart';
import 'main_page_state.dart';

const _accent = Color(0xFF1976D2);

Color _avatarColorFor(String text) {
  const colors = [
    Color(0xFF1976D2),
    Color(0xFF43A047),
    Color(0xFFE53935),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00897B),
  ];
  if (text.isEmpty) return colors[0];
  return colors[text.codeUnitAt(0) % colors.length];
}

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
            return const Center(
              child: Text('Nenhum contato ainda', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            itemCount: state.activeList.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 78),
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
    final color = _avatarColorFor(buddy.name);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: imageData == null
          ? CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                buddy.name.isNotEmpty ? buddy.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : CircleAvatar(radius: 26, backgroundImage: MemoryImage(imageData)),
      title: Text(
        buddy.name.isNotEmpty ? buddy.name : 'Sem nome',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(buddy.jidString, style: const TextStyle(fontSize: 12)),
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
            return const Center(
              child: Text('Nenhuma conversa ainda', style: TextStyle(color: Colors.grey)),
            );
          }
          return ListView.separated(
            itemCount: state.activeList.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 78),
            itemBuilder: (context, index) =>
                _buildChatItem(context, state.activeList[index]),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildChatItem(BuildContext context, UiChat chatItem) {
    final color = _avatarColorFor(chatItem.name);
    final hasUnread = false; // TODO: ligar ao estado real de não lidas

    return InkWell(
      onTap: () {
        // TODO: navegar para tela de chat
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color,
              child: Text(
                chatItem.name.isNotEmpty ? chatItem.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chatItem.name.isNotEmpty ? chatItem.name : 'Sem nome',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chatItem.jid,
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (hasUnread)
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
