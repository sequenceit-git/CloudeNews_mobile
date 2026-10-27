import 'package:atomic_x_core/atomicxcore.dart'
    show ConversationInfo, ConversationType, GroupStore;
import 'package:flutter/material.dart';
import 'package:tencent_chat_uikit/tencent_chat_uikit.dart' show ChatMessageInputConfig, ChatPage;

/// The room engine creates an IM group whose ID equals the room ID.
const _groupConversationIDPrefix = 'group_';

Widget buildRoomChatPage(String roomId) {
  return _RoomChatPage(roomId: roomId);
}

class _RoomChatPage extends StatefulWidget {
  const _RoomChatPage({required this.roomId});

  final String roomId;

  @override
  State<_RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends State<_RoomChatPage> {
  @override
  void initState() {
    super.initState();
    GroupStore.shared.joinGroup(groupID: widget.roomId);
  }

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      conversation: ConversationInfo(
        conversationID: '$_groupConversationIDPrefix${widget.roomId}',
        title: 'Chat',
        type: ConversationType.group,
      ),
      isShowAppBarActions: false,
      messageInputConfig: const ChatMessageInputConfig(
        isShowVideoRecorder: false,
        isShowFile: false,
        isShowAudioCall: false,
        isShowVideoCall: false,
      ),
    );
  }
}
