import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ChatItem {
  ChatItem({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.type,
    required this.at,
    this.text,
    this.url,
    this.name,
    this.size,
  });

  final String id;
  final String userId;
  final String displayName;
  final String type;
  final String? text;
  final String? url;
  final String? name;
  final int? size;
  final DateTime at;

  factory ChatItem.fromJson(Map<String, dynamic> json) => ChatItem(
        id: '${json['id'] ?? ''}',
        userId: '${json['userId'] ?? ''}',
        displayName: '${json['displayName'] ?? ''}',
        type: '${json['type'] ?? 'text'}',
        text: json['text'] as String?,
        url: json['url'] as String?,
        name: json['name'] as String?,
        size: json['size'] is int ? json['size'] as int : int.tryParse('${json['size'] ?? ''}'),
        at: DateTime.tryParse('${json['at'] ?? ''}') ?? DateTime.now(),
      );
}

class MeetingChatController {
  MeetingChatController({required this.ticket, required this.displayName, required this.onMeetingEnded});

  final MeetingTicket ticket;
  final String displayName;
  final VoidCallback onMeetingEnded;
  final items = ValueNotifier<List<ChatItem>>([]);
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  final error = ValueNotifier<String?>(null);
  var uploading = false;

  void connect() {
    final channel = WebSocketChannel.connect(ApiService.instance.meetingChatUri(ticket.meeting.meetingCode));
    _channel = channel;
    channel.sink.add(jsonEncode({
      'type': 'join',
      'userId': ticket.trtc.userId,
      'displayName': displayName,
    }));
    _subscription = channel.stream.listen(_onMessage, onError: (_) {
      error.value = 'Chat disconnected';
    }, onDone: () {
      error.value = 'Chat disconnected';
    });
  }

  void _onMessage(dynamic raw) {
    final decoded = jsonDecode('$raw');
    if (decoded is! Map) return;
    final data = Map<String, dynamic>.from(decoded);
    if (data['type'] == 'ended') {
      onMeetingEnded();
      return;
    }
    if (data['type'] != 'text' && data['type'] != 'image' && data['type'] != 'file') return;
    items.value = [...items.value, ChatItem.fromJson(data)];
  }

  void sendText(String value) {
    final text = value.trim();
    if (text.isEmpty) return;
    _channel?.sink.add(jsonEncode({'type': 'text', 'text': text}));
  }

  Future<void> sendFile(String path, String name) async {
    uploading = true;
    try {
      await ApiService.instance.uploadMeetingFile(
        meetingCode: ticket.meeting.meetingCode,
        userId: ticket.trtc.userId,
        displayName: displayName,
        filePath: path,
        fileName: name,
      );
    } on ApiException catch (error) {
      this.error.value = error.message;
    } finally {
      uploading = false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    items.dispose();
    error.dispose();
  }
}
class RoomChatPage extends StatefulWidget {
  const RoomChatPage({super.key, required this.chat});

  final MeetingChatController chat;

  @override
  State<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<RoomChatPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Chat'), backgroundColor: AppColors.card),
      body: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: chat.error,
            builder: (context, error, _) => error == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(error, style: const TextStyle(color: AppColors.danger)),
                  ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<ChatItem>>(
              valueListenable: chat.items,
              builder: (context, items, _) => ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                itemBuilder: (context, index) => _ChatBubble(
                  item: items[index],
                  mine: items[index].userId == chat.ticket.trtc.userId,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  IconButton(onPressed: () => _pickImage(chat), icon: const Icon(Icons.image_outlined)),
                  IconButton(onPressed: () => _pickFile(chat), icon: const Icon(Icons.attach_file)),
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (value) {
                        chat.sendText(value);
                        _input.clear();
                      },
                      decoration: const InputDecoration(hintText: 'Message'),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      chat.sendText(_input.text);
                      _input.clear();
                    },
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _pickImage(MeetingChatController chat) async {
  final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
  if (image == null) return;
  await chat.sendFile(image.path, image.name);
}

Future<void> _pickFile(MeetingChatController chat) async {
  final picked = await FilePicker.platform.pickFiles(withData: false);
  final file = picked?.files.single;
  final path = file?.path;
  if (file == null || path == null) return;
  await chat.sendFile(path, file.name);
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.item, required this.mine});

  final ChatItem item;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final url = item.url == null ? null : ApiService.instance.absoluteApiUrl(item.url!);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.displayName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            if (item.type == 'image' && url != null)
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _ImagePage(url: url))),
                child: Image.network(url, height: 160, fit: BoxFit.cover),
              )
            else if (item.type == 'file' && url != null)
              InkWell(
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Text(item.name ?? 'File', style: const TextStyle(color: AppColors.cyan, decoration: TextDecoration.underline)),
              )
            else
              Text(item.text ?? '', style: const TextStyle(color: AppColors.text)),
          ],
        ),
      ),
    );
  }
}

class _ImagePage extends StatelessWidget {
  const _ImagePage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(child: InteractiveViewer(child: Image.network(url))),
    );
  }
}
