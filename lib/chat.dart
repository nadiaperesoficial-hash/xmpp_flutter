import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:simple_chat/const.dart';
import 'package:simple_chat/repo/ui_chat.dart';
import 'package:simple_chat/roster/roster_repo.dart';

class Chat extends StatelessWidget {
  final UiBuddy buddy;
  final UiChat uiChat;

  const Chat({Key? key, required this.buddy, required this.uiChat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(buddy.name, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ChatScreen(buddy: buddy, uiChat: uiChat),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final AnimationController animationController;
  final bool isIncoming;
  final String? senderName;

  const ChatMessage({
    Key? key,
    required this.text,
    required this.animationController,
    this.isIncoming = false,
    this.senderName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName = senderName ?? 'Você';
    final contentColor = isIncoming ? greyColor : greyColor2;

    final messageContent = Container(
      padding: EdgeInsets.only(top: 10, bottom: 10, right: isIncoming ? 10 : 20, left: 10),
      decoration: BoxDecoration(color: contentColor, borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isIncoming ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (isIncoming)
            Text(displayName, style: Theme.of(context).textTheme.titleMedium),
          Container(margin: const EdgeInsets.only(top: 5), child: Text(text)),
        ],
      ),
    );

    final children = isIncoming
        ? [
            Container(margin: const EdgeInsets.only(right: 16), child: CircleAvatar(child: Text(displayName.isNotEmpty ? displayName[0] : '?'))),
            Flexible(child: messageContent),
          ]
        : [Flexible(child: messageContent)];

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animationController, curve: Curves.easeOut),
      axisAlignment: 0.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: children,
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final UiBuddy buddy;
  final UiChat uiChat;

  const ChatScreen({Key? key, required this.buddy, required this.uiChat}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    widget.uiChat.uiMessages.listen((msgs) {
      if (!mounted) return;
      setState(() {
        _messages.clear();
        for (final m in msgs.reversed) {
          final ctrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
          _messages.insert(0, ChatMessage(
            text: m.messageBody ?? '',
            animationController: ctrl,
            isIncoming: !(m.fromMe),
            senderName: m.fromMe ? null : widget.buddy.name,
          ));
          ctrl.forward();
        }
      });
    });
  }

  @override
  void dispose() {
    for (final m in _messages) m.animationController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;
    _textController.clear();
    setState(() => _isComposing = false);
    widget.uiChat.sendMessage(text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.secondary;
    return Column(
      children: [
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (_, i) => _messages[i],
          ),
        ),
        const Divider(height: 1),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: IconTheme(
            data: IconThemeData(color: iconColor),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Flexible(
                  child: TextField(
                    controller: _textController,
                    onChanged: (t) => setState(() => _isComposing = t.isNotEmpty),
                    onSubmitted: _handleSubmitted,
                    decoration: const InputDecoration.collapsed(hintText: 'Enviar mensagem'),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Theme.of(context).platform == TargetPlatform.iOS
                      ? CupertinoButton(
                          onPressed: _isComposing ? () => _handleSubmitted(_textController.text) : null,
                          child: const Text('Enviar'),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _isComposing ? () => _handleSubmitted(_textController.text) : null,
                        ),
                ),
              ]),
            ),
          ),
        ),
      ],
    );
  }
}
