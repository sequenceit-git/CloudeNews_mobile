class HostUser {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;

  const HostUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
  });

  factory HostUser.fromJson(Map<String, dynamic> json) => HostUser(
        id: '${json['id'] ?? ''}',
        username: '${json['username'] ?? ''}',
        displayName: '${json['displayName'] ?? json['username'] ?? ''}',
        email: json['email'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
      );

  String get label => displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : (email ?? 'Host'));
}

class MeetingDetails {
  final String id;
  final String meetingCode;
  final String title;
  final String hostName;
  final String? hostUserId;
  final String status;

  const MeetingDetails({
    required this.id,
    required this.meetingCode,
    required this.title,
    required this.hostName,
    required this.status,
    this.hostUserId,
  });

  factory MeetingDetails.fromJson(Map<String, dynamic> json) => MeetingDetails(
        id: '${json['id'] ?? ''}',
        meetingCode: '${json['meetingCode'] ?? ''}',
        title: '${json['title'] ?? ''}',
        hostName: '${json['hostName'] ?? ''}',
        hostUserId: json['hostUserId'] as String?,
        status: '${json['status'] ?? 'ACTIVE'}',
      );
}

class TrtcCredentials {
  final int sdkAppId;
  final String userId;
  final String userSig;
  final String roomId;
  final String? displayName;
  final bool isHost;

  const TrtcCredentials({
    required this.sdkAppId,
    required this.userId,
    required this.userSig,
    required this.roomId,
    required this.isHost,
    this.displayName,
  });

  /// The server sends a numeric `roomId` plus its string form `strRoomId`;
  /// TUIRoomKit takes string room IDs, and every client must use the same one.
  factory TrtcCredentials.fromJson(Map<String, dynamic> json, {required String meetingCode}) {
    final strRoomId = json['strRoomId']?.toString() ?? '';
    final numericRoomId = json['roomId']?.toString() ?? '';
    final roomId = strRoomId.isNotEmpty
        ? strRoomId
        : (numericRoomId.isNotEmpty && numericRoomId != '0' ? numericRoomId : meetingCode.replaceAll('-', ''));
    return TrtcCredentials(
      sdkAppId: int.tryParse('${json['sdkAppId'] ?? ''}') ?? 0,
      userId: '${json['userId'] ?? ''}',
      userSig: '${json['userSig'] ?? ''}',
      roomId: roomId,
      displayName: json['displayName'] as String?,
      isHost: json['isHost'] == true,
    );
  }
}

class MeetingTicket {
  final MeetingDetails meeting;
  final TrtcCredentials trtc;

  const MeetingTicket(this.meeting, this.trtc);

  factory MeetingTicket.fromJson(Map<String, dynamic> json) {
    final meeting = MeetingDetails.fromJson(Map<String, dynamic>.from(json['meeting'] as Map));
    final trtc = TrtcCredentials.fromJson(
      Map<String, dynamic>.from(json['trtc'] as Map),
      meetingCode: meeting.meetingCode,
    );
    return MeetingTicket(meeting, trtc);
  }
}

class MeetingValidation {
  final bool valid;
  final String? reason;

  const MeetingValidation({required this.valid, this.reason});
}
