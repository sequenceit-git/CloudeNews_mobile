import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/env.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_scope.dart';
import '../services/meeting_file_downloader.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

class MeetingChatMessage {
  final String id;
  final String type; // 'text' | 'image' | 'file' | 'ended'
  final String userId;
  final String displayName;
  final String? text;
  final String? url;
  final String? name;
  final int? size;
  final DateTime at;

  const MeetingChatMessage({
    required this.id,
    required this.type,
    required this.userId,
    required this.displayName,
    this.text,
    this.url,
    this.name,
    this.size,
    required this.at,
  });

  factory MeetingChatMessage.fromJson(Map<String, dynamic> json) {
    return MeetingChatMessage(
      id: '${json['id'] ?? DateTime.now().millisecondsSinceEpoch}',
      type: '${json['type'] ?? 'text'}',
      userId: '${json['userId'] ?? ''}',
      displayName: '${json['displayName'] ?? 'Guest'}',
      text: json['text'] as String?,
      url: json['url'] as String?,
      name: json['name'] as String?,
      size: json['size'] as int?,
      at: json['at'] != null ? DateTime.tryParse('${json['at']}') ?? DateTime.now() : DateTime.now(),
    );
  }
}

class MeetingChatSheet extends StatefulWidget {
  const MeetingChatSheet({
    super.key,
    required this.meetingCode,
    required this.userId,
    required this.displayName,
    this.initialMessages,
    this.onMessageReceived,
    this.isFullScreen = false,
    this.onRoomEnded,
    this.onUserIdentified,
  });

  final String meetingCode;
  final String userId;
  final String displayName;
  final List<MeetingChatMessage>? initialMessages;
  final void Function(MeetingChatMessage message)? onMessageReceived;
  final bool isFullScreen;
  final VoidCallback? onRoomEnded;
  final void Function(String userId, String displayName)? onUserIdentified;

  @override
  State<MeetingChatSheet> createState() => _MeetingChatSheetState();
}

class _MeetingChatSheetState extends State<MeetingChatSheet> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  late final List<MeetingChatMessage> _messages;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _channelSub;
  bool _uploading = false;
  final Map<String, String> _localFilePaths = {};
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _messages = List<MeetingChatMessage>.from(widget.initialMessages ?? []);
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channelSub?.cancel();
    _channel?.sink.close();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _connectWebSocket() {
    final baseUri = Uri.parse(Env.apiBaseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = baseUri.replace(
      scheme: wsScheme,
      path: '${baseUri.path}/meetings/${Uri.encodeComponent(widget.meetingCode)}/chat',
    );

    try {
      final channel = WebSocketChannel.connect(wsUri);
      _channel = channel;

      // 1. Initial join handshake message
      channel.sink.add(jsonEncode({
        'type': 'join',
        'userId': widget.userId,
        'displayName': widget.displayName,
      }));

      // 2. Listen for messages
      _channelSub = channel.stream.listen(
        (data) {
          if (!mounted) return;
          try {
            final json = jsonDecode(data.toString());
            if (json is Map<String, dynamic>) {
              final msg = MeetingChatMessage.fromJson(json);
              if (msg.type == 'ended') {
                widget.onRoomEnded?.call();
                return;
              }
              if (msg.userId.isNotEmpty && msg.displayName.isNotEmpty) {
                widget.onUserIdentified?.call(msg.userId, msg.displayName);
              }
              setState(() => _messages.add(msg));
              widget.onMessageReceived?.call(msg);
              _scrollToBottom();
            }
          } catch (_) {
            // Ignore malformed payloads
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty || _channel == null) return;
    _channel?.sink.add(jsonEncode({'type': 'text', 'text': text}));
    _textController.clear();
  }

  Future<void> _pickAndSendImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) {
        await _uploadFile(File(picked.path), picked.name);
      }
    } catch (_) {}
  }

  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        await _uploadFile(File(path), result.files.single.name);
      }
    } catch (_) {}
  }

  Future<void> _uploadFile(File file, String filename) async {
    final strings = context.strings;
    final length = await file.length();
    if (length > 15 * 1024 * 1024) {
      if (mounted) showErrorSnack(context, strings.fileSizeLimitExceeded);
      return;
    }

    setState(() => _uploading = true);
    try {
      final uploadUri = Uri.parse('${Env.apiBaseUrl}/meetings/${Uri.encodeComponent(widget.meetingCode)}/files');
      final request = http.MultipartRequest('POST', uploadUri);
      request.fields['userId'] = widget.userId;
      request.fields['displayName'] = widget.displayName;
      request.files.add(await http.MultipartFile.fromPath('file', file.path, filename: filename));

      final res = await request.send();
      final resBody = await res.stream.bytesToString();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Chat Upload Error] status: ${res.statusCode}, body: $resBody');
        if (mounted) showErrorSnack(context, 'Upload failed (${res.statusCode})');
      }
    } catch (e) {
      debugPrint('[Chat Upload Exception] $e');
      if (mounted) showErrorSnack(context, 'Upload error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _handleDownloadAndOpen(MeetingChatMessage msg, {bool openImmediately = false}) async {
    final url = msg.url;
    if (url == null || url.isEmpty) return;
    final fullUrl = url.startsWith('/') ? '${Env.webOrigin}$url' : url;
    final filename = msg.name ?? (msg.type == 'image' ? 'image_${msg.id}.jpg' : 'file_${msg.id}');

    try {
      String localPath = _localFilePaths[msg.id] ?? '';
      if (localPath.isEmpty || !MeetingFileDownloader.instance.isFileDownloaded(localPath)) {
        localPath = await MeetingFileDownloader.instance.resolveLocalPath(filename);
      }

      if (MeetingFileDownloader.instance.isFileDownloaded(localPath)) {
        _localFilePaths[msg.id] = localPath;
        if (openImmediately) {
          final res = await MeetingFileDownloader.instance.openFile(localPath);
          if (res.type != ResultType.done && mounted) {
            showErrorSnack(context, res.message);
          }
        } else {
          if (mounted) {
            showSuccessSnack(context, '${context.strings.fileSavedNotice}: $filename');
          }
        }
        return;
      }

      setState(() => _downloadProgress[msg.id] = 0.05);

      await MeetingFileDownloader.instance.downloadFile(
        url: fullUrl,
        localPath: localPath,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress[msg.id] = p);
        },
      );

      if (mounted) {
        setState(() {
          _localFilePaths[msg.id] = localPath;
          _downloadProgress.remove(msg.id);
        });
        showSuccessSnack(context, '${context.strings.fileSavedNotice}: $filename');
      }

      if (openImmediately) {
        final res = await MeetingFileDownloader.instance.openFile(localPath);
        if (res.type != ResultType.done && mounted) {
          showErrorSnack(context, res.message);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloadProgress.remove(msg.id));
        showErrorSnack(context, 'Download error: $e');
      }
    }
  }

  void _showImageViewerDialog(MeetingChatMessage msg) {
    final url = msg.url;
    if (url == null || url.isEmpty) return;
    final imgUrl = url.startsWith('/') ? '${Env.webOrigin}$url' : url;
    final strings = context.strings;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final localPath = _localFilePaths[msg.id];
          final isDownloaded = localPath != null && MeetingFileDownloader.instance.isFileDownloaded(localPath);
          final progress = _downloadProgress[msg.id];
          final isDownloading = progress != null;

          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: Image.network(
                        imgUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, prog) {
                          if (prog == null) return child;
                          return const Center(child: CircularProgressIndicator(color: AppColors.cyan));
                        },
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 48),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Row(
                        children: [
                          Text(
                            msg.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 24),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: Colors.black.withValues(alpha: 0.7),
                      child: Center(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isDownloaded ? AppColors.cyan.withValues(alpha: 0.2) : AppColors.primary,
                            foregroundColor: isDownloaded ? AppColors.cyan : Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isDownloading
                              ? null
                              : () async {
                                  await _handleDownloadAndOpen(msg, openImmediately: false);
                                  setDialogState(() {});
                                },
                          icon: isDownloading
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Icon(isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded, size: 20),
                          label: Text(
                            isDownloaded
                                ? strings.downloaded
                                : isDownloading
                                    ? strings.downloading
                                    : strings.downloadFile,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: AppColors.background,
      child: Container(
        height: widget.isFullScreen ? double.infinity : MediaQuery.sizeOf(context).height * 0.75,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: const Color(0xFF131826),
          borderRadius: widget.isFullScreen ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(20)),
          border: widget.isFullScreen ? null : Border.all(color: AppColors.cyan.withValues(alpha: 0.25), width: 1),
          boxShadow: widget.isFullScreen
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 4,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Drag handle (only for bottom sheet mode)
            if (!widget.isFullScreen)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0F1420),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.cyan),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    strings.chatTitle,
                    style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.cardBorder),
            // Messages List
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        strings.typeMessageHint,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 13),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMe = msg.userId == widget.userId;
                        final localPath = _localFilePaths[msg.id];
                        final isDownloaded = localPath != null &&
                            MeetingFileDownloader.instance.isFileDownloaded(localPath);
                        final progress = _downloadProgress[msg.id];

                        return _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          timeStr: _formatTime(msg.at),
                          formattedSize: _formatSize(msg.size),
                          isDownloaded: isDownloaded,
                          downloadProgress: progress,
                          onTapImage: () => _showImageViewerDialog(msg),
                          onTapFile: () => _handleDownloadAndOpen(msg, openImmediately: false),
                          onDownloadFile: () => _handleDownloadAndOpen(msg, openImmediately: false),
                          strings: strings,
                        );
                      },
                    ),
            ),
            if (_uploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                    ),
                    const SizedBox(width: 8),
                    Text(strings.uploadingFile, style: const TextStyle(color: AppColors.cyan, fontSize: 12)),
                  ],
                ),
              ),
            const Divider(height: 1, color: AppColors.cardBorder),
            // Bottom Input Bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
                color: AppColors.background,
                child: Row(
                  children: [
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.cyan, size: 24),
                      color: AppColors.card,
                      onSelected: (val) {
                        if (val == 'photo') _pickAndSendImage();
                        if (val == 'file') _pickAndSendFile();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'photo',
                          child: Row(
                            children: [
                              const Icon(Icons.photo_outlined, size: 18, color: AppColors.primaryLight),
                              const SizedBox(width: 10),
                              Text(strings.attachPhoto, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'file',
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.cyan),
                              const SizedBox(width: 10),
                              Text(strings.attachFile, style: const TextStyle(color: AppColors.text, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        child: TextField(
                          controller: _textController,
                          style: const TextStyle(color: AppColors.text, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: strings.typeMessageHint,
                            hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.primary, size: 22),
                      onPressed: _sendText,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.timeStr,
    required this.formattedSize,
    required this.isDownloaded,
    required this.downloadProgress,
    required this.onTapImage,
    required this.onTapFile,
    required this.onDownloadFile,
    required this.strings,
  });

  final MeetingChatMessage message;
  final bool isMe;
  final String timeStr;
  final String formattedSize;
  final bool isDownloaded;
  final double? downloadProgress;
  final VoidCallback onTapImage;
  final VoidCallback onTapFile;
  final VoidCallback onDownloadFile;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final senderInitial = message.displayName.isNotEmpty ? message.displayName.characters.first.toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary.withValues(alpha: 0.3),
              child: Text(
                senderInitial,
                style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.displayName,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                Container(
                  padding: message.type == 'image' ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(isMe ? 14 : 2),
                      bottomRight: Radius.circular(isMe ? 2 : 14),
                    ),
                    border: Border.all(color: isMe ? Colors.transparent : AppColors.cardBorder),
                  ),
                  child: _buildContent(context),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                  child: Text(
                    timeStr,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe)
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primary,
              child: Text(
                senderInitial,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (message.type == 'image' && message.url != null) {
      final imgUrl = message.url!.startsWith('/') ? '${Env.webOrigin}${message.url}' : message.url!;
      final isDownloading = downloadProgress != null;

      return Stack(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTapImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imgUrl,
                width: 180,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: 160,
                    height: 100,
                    color: AppColors.cardBorder.withValues(alpha: 0.3),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: 160,
                  height: 100,
                  color: AppColors.cardBorder,
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image, color: AppColors.textDim, size: 24),
                      SizedBox(height: 4),
                      Text('Image unavailable', style: TextStyle(color: AppColors.textDim, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: InkWell(
              onTap: isDownloading ? null : onDownloadFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: isDownloading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.cyan),
                      )
                    : Icon(
                        isDownloaded ? Icons.check_circle : Icons.download_rounded,
                        size: 14,
                        color: isDownloaded ? AppColors.cyan : Colors.white,
                      ),
              ),
            ),
          ),
        ],
      );
    }

    if (message.type == 'file' && message.url != null) {
      final isDownloading = downloadProgress != null;

      return InkWell(
        onTap: onTapFile,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file, size: 22, color: AppColors.cyan),
              ),
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.name ?? 'Document',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (formattedSize.isNotEmpty)
                          Text(
                            formattedSize,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        if (formattedSize.isNotEmpty) const SizedBox(width: 6),
                        Text(
                          isDownloaded ? strings.downloaded : strings.downloadFile,
                          style: TextStyle(
                            color: isDownloaded ? AppColors.cyan : AppColors.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: isDownloading ? null : onDownloadFile,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cyan),
                        )
                      : Icon(
                          isDownloaded ? Icons.check_circle_rounded : Icons.download_rounded,
                          size: 20,
                          color: isDownloaded ? AppColors.cyan : Colors.white70,
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Text(
      message.text ?? '',
      style: const TextStyle(color: AppColors.text, fontSize: 14, height: 1.35),
    );
  }
}

