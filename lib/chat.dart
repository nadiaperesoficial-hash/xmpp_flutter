import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:simple_chat/const.dart';
import 'package:simple_chat/settings/settings.dart';
// Import corrigido para o novo plugin
import 'package:xmpp_plugin/xmpp_plugin.dart' as xmpp;
import 'package:simple_chat/service_locator/service_locator.dart';

const String _selfName = "Self Name";

class Chat extends StatelessWidget {
  final xmpp.Buddy buddy;

  // Parâmetro key agora é opcional com Key?
  const Chat({Key? key, required this.buddy}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CHAT',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ChatScreen(buddy: buddy),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final xmpp.Buddy? from;
  final String text;
  final AnimationController animationController;
  final bool isIncoming; // Tornado final

  const ChatMessage({
    Key? key,
    required this.text,
    required this.animationController,
    this.from,
  }) : isIncoming = from != null, super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayName = (from != null)
        ? (from!.name ?? from!.jid.userAtDomain)
        : _selfName;
    final initials = displayName[0] ?? "X";
    final contentColor = isIncoming ? greyColor : greyColor2;

    final avatar = Container(
      margin: const EdgeInsets.only(right: 16.0),
      child: CircleAvatar(child: Text(initials)),
    );

    final nameWidget = Text(
      displayName,
      // subhead substituído por titleMedium
      style: Theme.of(context).textTheme.titleMedium,
    );

    final textWidget = Container(
      margin: const EdgeInsets.only(top: 5.0),
      child: Text(text),
    );

    final List<Widget> messageChildren;
    if (from == null) {
      messageChildren = [textWidget];
    } else {
      messageChildren = [nameWidget, textWidget];
    }

    final messageContent = Container(
      alignment: Alignment.centerRight,
      padding: EdgeInsets.only(
        top: 10.0,
        bottom: 10,
        right: isIncoming ? 10 : 20,
        left: 10,
      ),
      decoration: BoxDecoration(
        color: contentColor,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment:
            (from == null) ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: messageChildren,
      ),
    );

    final List<Widget> children;
    if (from == null) {
      children = [messageContent];
    } else {
      children = [avatar, messageContent];
    }

    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: animationController,
        curve: Curves.easeOut,
      ),
      axisAlignment: 0.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          mainAxisAlignment:
              isIncoming ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: children,
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final xmpp.Buddy buddy;

  const ChatScreen({Key? key, required this.buddy}) : super(key: key);

  @override
  State<ChatScreen> createState() => ChatScreenState(buddy: buddy);
}

class ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final xmpp.Buddy buddy;
  final _settings = sl.get<Settings>();
  xmpp.MessageHandler? _messageHandler; // Tornado nullable

  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();
  bool _isComposing = false;

  ChatScreenState({required this.buddy});

  @override
  void initState() {
    super.initState();
    _initMessageHandler();
  }

  void _handleSubmitted(String text) {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    _messageHandler?.sendMessage(buddy.jid, text); // Use ?. para segurança
    final message = ChatMessage(
      text: text,
      animationController: AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      ),
    );
    setState(() {
      _messages.insert(0, message);
    });
    message.animationController.forward();
  }

  void _handleIncoming(xmpp.MessageStanza messageStanza) {
    final message = ChatMessage(
      text: messageStanza.body,
      animationController: AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      ),
      from: buddy,
    );
    setState(() {
      _messages.insert(0, message);
    });
    message.animationController.forward();
  }

  @override
  void dispose() {
    for (var message in _messages) {
      message.animationController.dispose();
    }
    _textController.dispose(); // Boa prática liberar o controller
    super.dispose();
  }

  Widget _buildTextComposer() {
    // accentColor substituído por colorScheme.secondary
    final iconColor = Theme.of(context).colorScheme.secondary;
    return IconTheme(
      data: IconThemeData(color: iconColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(children: [
          Flexible(
            child: TextField(
              controller: _textController,
              onChanged: (String text) {
                setState(() {
                  _isComposing = text.isNotEmpty;
                });
              },
              onSubmitted: _handleSubmitted,
              decoration: const InputDecoration.collapsed(
                hintText: "Send a message",
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Theme.of(context).platform == TargetPlatform.iOS
                ? CupertinoButton(
                    child: const Text("Send"),
                    onPressed: _isComposing
                        ? () => _handleSubmitted(_textController.text)
                        : null,
                  )
                : IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isComposing
                        ? () => _handleSubmitted(_textController.text)
                        : null,
                  ),
          ),
        ]),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Column(children: [
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.all(8.0),
              reverse: true,
              itemBuilder: (_, int index) => _messages[index],
              itemCount: _messages.length,
            ),
          ),
          const Divider(height: 1.0),
          Container(
            decoration: BoxDecoration(color: Theme.of(context).cardColor),
            child: _buildTextComposer(),
          ),
        ]),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              )
            : null,
      ),
    );
  }

  Future<void> _initMessageHandler() async {
    final connection =
        xmpp.Connection.getInstance(await _settings.getAccountData());
    _messageHandler = xmpp.MessageHandler.getInstance(connection);
    _messageHandler?.messagesStream.listen((message) {
      if (message.fromJid.userAtDomain == buddy.jid.userAtDomain &&
          message.body != null) {
        _handleIncoming(message);
      }
    });
  }
}
