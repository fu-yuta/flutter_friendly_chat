import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:friendly_chat/model/chat.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(
    FrendlyChatApp(),
  );
}

final ThemeData kIOSTheme = ThemeData(
  primarySwatch: Colors.orange,
  primaryColor: Colors.grey[100],
  primaryColorBrightness: Brightness.light,
);

final ThemeData kDefaultTheme = ThemeData(
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.purple)
      .copyWith(secondary: Colors.orangeAccent[400]),
);

class FrendlyChatApp extends StatelessWidget {
  const FrendlyChatApp({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "FrendlyChat",
      theme: defaultTargetPlatform == TargetPlatform.iOS
          ? kIOSTheme
          : kDefaultTheme,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _textController = TextEditingController();
  final _updateTextController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final FocusNode _focusNode = FocusNode();
  final FocusNode _updateFocusNode = FocusNode();
  bool _isComposing = false;
  final String chatUri = defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080/v1/chat/'
      : 'http://127.0.0.1:8080/v1/chat/';

  @override
  void initState() {
    super.initState();
    _getAllChatsRequester();
  }

  @override
  void dispose() {
    for (var message in _messages) {
      message.animationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("FrendlyChat"),
        elevation: Theme.of(context).platform == TargetPlatform.iOS ? 0.0 : 4.0,
      ),
      body: Container(
        child: Column(
          children: [
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                reverse: true,
                itemBuilder: (_, index) {
                  return Container(
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            child: _messages[index],
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: Text("${_messages[index].text}を変更しますか?"),
                                    content: TextField(
                                      controller: _updateTextController,
                                      decoration:
                                          const InputDecoration.collapsed(hintText: "Change a message"),
                                      focusNode: _updateFocusNode,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text("Cancel")
                                      ),
                                      TextButton(
                                        onPressed: () => {
                                          _updateChatRequester(index, _updateTextController.text),
                                          Navigator.pop(context)
                                        },
                                        child: Text("OK")
                                      ),
                                    ],
                                  );
                                });
                            },
                          ),
                        ),
                        IconButton(
                            onPressed: () => _deleteChatRequster(index),
                            icon: Icon(Icons.delete_rounded)),
                      ],
                    ),
                  );
                },
                itemCount: _messages.length,
              ),
            ),
            const Divider(height: 1.0),
            Container(
                decoration: BoxDecoration(color: Theme.of(context).cardColor),
                child: _buildTextComposer()),
          ],
        ),
        decoration: Theme.of(context).platform == TargetPlatform.iOS
            ? BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTextComposer() {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).colorScheme.secondary),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            Flexible(
              child: TextField(
                controller: _textController,
                onChanged: (text) {
                  setState(() {
                    _isComposing = text.isNotEmpty;
                  });
                },
                onSubmitted: _isComposing ? _postChatRequester : null,
                decoration:
                    const InputDecoration.collapsed(hintText: "Send a message"),
                focusNode: _focusNode,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      child: const Text("Send"),
                      onPressed: _isComposing
                          ? () => _postChatRequester(_textController.text)
                          : null,
                    )
                  : IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isComposing
                          ? () => _postChatRequester(_textController.text)
                          : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmitted(String text, int id, {int index = 0}) {
    _textController.clear();
    setState(() {
      _isComposing = false;
    });
    var message = ChatMessage(
      text: text,
      id: id,
      animationController: AnimationController(
        duration: const Duration(milliseconds: 700),
        vsync: this,
      ),
    );
    setState(() {
      _messages.insert(index, message);
    });
    _focusNode.requestFocus();
    message.animationController.forward();
  }

  void _getAllChatsRequester() async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
    };

    final response = await http.get(Uri.parse(chatUri), headers: headers);

    if (response.statusCode == 200) {
      Map<String, dynamic> decoded = json.decode(response.body);
      _messages.clear();
      if (decoded['chats'] != null) {
        for (var item in decoded['chats']) {
          var chatResponse = ChatResponse.fromJson(item);
          _handleSubmitted(chatResponse.message, chatResponse.id);
        }
      }
    } else {
      throw Exception('Get All Chats Fail');
    }
  }

  void _postChatRequester(String text) async {
    Map<String, String> headers = {
      "Content-Type": "application/json",
    };

    var request = ChatRequest(userName: "Your Name", message: text);

    final response = await http.post(Uri.parse(chatUri),
        body: json.encode(request.toJson()), headers: headers);

    if (response.statusCode == 200) {
      Map<String, dynamic> decoded = json.decode(response.body);
      var chatResponse = ChatResponse.fromJson(decoded);
      _handleSubmitted(chatResponse.message, chatResponse.id);
    } else {
      throw Exception('Post Chats Fail');
    }
  }

  void _deleteChatRequster(int index) async {
    var deleteMessage = _messages[index];
    var deleteUri = Uri.parse(chatUri + deleteMessage.id.toString());

    Map<String, String> headers = {
      "Content-Type": "application/json",
    };

    final response = await http.delete(deleteUri, headers: headers);

    if (response.statusCode == 200) {
      setState(() {
        _messages.removeAt(index);
      });
    } else {
      throw Exception('Delete Chats Fail');
    }
  }

  void _updateChatRequester(int index, String text) async {
    var updateMessage = _messages[index];
    var updateUri = Uri.parse(chatUri + updateMessage.id.toString());

    Map<String, String> headers = {
      "Content-Type": "application/json",
    };

    var request = UpdateChatRequest(message: text);

    final response = await http.put(updateUri, body: json.encode(request.toJson()), headers: headers);

    if (response.statusCode == 200) {
      Map<String, dynamic> decoded = json.decode(response.body);
      var chatResponse = ChatResponse.fromJson(decoded);
      _updateTextController.clear();

      setState(() {
        // _messages[index].text = chatResponse.messageだと再描画されない?
        _messages.removeAt(index);
        _handleSubmitted(chatResponse.message, chatResponse.id, index: index);
      });
    } else {
      throw Exception('Update Chats Fail');
    }
  }
}

class ChatMessage extends StatelessWidget {
  String _name = 'Your Name';

  ChatMessage({
    required this.text,
    required this.animationController,
    required this.id,
    Key? key,
  }) : super(key: key);
  final text;
  final AnimationController animationController;
  final int id;

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor:
          CurvedAnimation(parent: animationController, curve: Curves.easeOut),
      axisAlignment: 0.0,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(child: Text(_name[0])),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_name, style: Theme.of(context).textTheme.headline4),
                  Container(
                    margin: const EdgeInsets.only(top: 5.0),
                    child: Text(text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
