import 'package:flutter/widgets.dart';

enum AppLanguage {
  en(Locale('en')),
  zh(Locale('zh'));

  final Locale locale;
  const AppLanguage(this.locale);

  static AppLanguage fromLocale(Locale locale) =>
      locale.languageCode == 'zh' ? AppLanguage.zh : AppLanguage.en;
}

class AppStrings {
  final String appName;
  final String tagline;
  final String switchLanguage;
  final String termsNotice;

  final String joinMeetingTitle;
  final String joinMeetingDesc;
  final String meetingCodeLabel;
  final String meetingCodeHint;
  final String nextStepBtn;
  final String roomValidating;
  final String roomNotFound;
  final String inputRequiredError;
  final String hostPrompt;
  final String hostSignInLink;

  final String lobbyTitle;
  final String lobbyDesc;
  final String linkDetectedBadge;
  final String roomPrefix;
  final String displayNameLabel;
  final String displayNameHint;
  final String nameRequiredError;
  final String micOn;
  final String micOff;
  final String videoOn;
  final String videoOff;
  final String cameraReady;
  final String cameraOffNotice;
  final String enterRoomBtn;
  final String joiningNotice;

  final String hostLoginTitle;
  final String hostLoginDesc;
  final String usernameLabel;
  final String usernameHint;
  final String passwordLabel;
  final String passwordHint;
  final String signInButton;
  final String authMissingFields;

  final String welcomeGreeting;
  final String signOut;
  final String instantMeetingTitle;
  final String instantMeetingDesc;
  final String startInstantMeetingBtn;
  final String trtcStatusTitle;
  final String trtcStatusDesc;
  final String Function(String host) meetingTitleFor;

  final String permissionDenied;
  final String roomLoginFailed;

  // In-room controls
  final String switchCamera;
  final String speakerOn;
  final String earpieceOn;
  final String startScreenShare;
  final String stopScreenShare;
  final String screenShareActive;
  final String Function(String name) otherUserSharingScreen;
  final String leaveMeeting;
  final String endMeetingForAll;
  final String confirmLeave;
  final String confirmEnd;
  final String cancel;
  final String copyMeetingCode;
  final String codeCopied;
  final String membersTitle;
  final String meBadge;
  final String hostBadge;
  final String hostEndedMeetingNotice;
  final String soloTimeoutNotice;
  final String transferHostTitle;
  final String transferHostSubtitle;
  final String transferAndLeave;
  final String youAreNowHost;
  final String aloneInMeeting;
  final String leaveAndEnd;

  // Chat & file sharing
  final String chatTitle;
  final String typeMessageHint;
  final String sendBtn;
  final String attachPhoto;
  final String attachFile;
  final String uploadingFile;
  final String fileSizeLimitExceeded;
  final String downloadFile;
  final String downloading;
  final String downloaded;
  final String openFile;
  final String fileSavedNotice;
  final String openInGallery;

  // Active meeting conflict
  final String activeMeetingOngoingTitle;
  final String Function(String code) activeMeetingOngoingDesc;
  final String rejoinMeetingBtn;
  final String endPreviousAndStartBtn;

  const AppStrings({
    required this.appName,
    required this.tagline,
    required this.switchLanguage,
    required this.termsNotice,
    required this.joinMeetingTitle,
    required this.joinMeetingDesc,
    required this.meetingCodeLabel,
    required this.meetingCodeHint,
    required this.nextStepBtn,
    required this.roomValidating,
    required this.roomNotFound,
    required this.inputRequiredError,
    required this.hostPrompt,
    required this.hostSignInLink,
    required this.lobbyTitle,
    required this.lobbyDesc,
    required this.linkDetectedBadge,
    required this.roomPrefix,
    required this.displayNameLabel,
    required this.displayNameHint,
    required this.nameRequiredError,
    required this.micOn,
    required this.micOff,
    required this.videoOn,
    required this.videoOff,
    required this.cameraReady,
    required this.cameraOffNotice,
    required this.enterRoomBtn,
    required this.joiningNotice,
    required this.hostLoginTitle,
    required this.hostLoginDesc,
    required this.usernameLabel,
    required this.usernameHint,
    required this.passwordLabel,
    required this.passwordHint,
    required this.signInButton,
    required this.authMissingFields,
    required this.welcomeGreeting,
    required this.signOut,
    required this.instantMeetingTitle,
    required this.instantMeetingDesc,
    required this.startInstantMeetingBtn,
    required this.trtcStatusTitle,
    required this.trtcStatusDesc,
    required this.meetingTitleFor,
    required this.permissionDenied,
    required this.roomLoginFailed,
    required this.switchCamera,
    required this.speakerOn,
    required this.earpieceOn,
    required this.startScreenShare,
    required this.stopScreenShare,
    required this.screenShareActive,
    required this.otherUserSharingScreen,
    required this.leaveMeeting,
    required this.endMeetingForAll,
    required this.confirmLeave,
    required this.confirmEnd,
    required this.cancel,
    required this.copyMeetingCode,
    required this.codeCopied,
    required this.membersTitle,
    required this.meBadge,
    required this.hostBadge,
    required this.hostEndedMeetingNotice,
    required this.soloTimeoutNotice,
    required this.transferHostTitle,
    required this.transferHostSubtitle,
    required this.transferAndLeave,
    required this.youAreNowHost,
    required this.aloneInMeeting,
    required this.leaveAndEnd,
    required this.chatTitle,
    required this.typeMessageHint,
    required this.sendBtn,
    required this.attachPhoto,
    required this.attachFile,
    required this.uploadingFile,
    required this.fileSizeLimitExceeded,
    required this.downloadFile,
    required this.downloading,
    required this.downloaded,
    required this.openFile,
    required this.fileSavedNotice,
    required this.openInGallery,
    required this.activeMeetingOngoingTitle,
    required this.activeMeetingOngoingDesc,
    required this.rejoinMeetingBtn,
    required this.endPreviousAndStartBtn,
  });

  static AppStrings of(AppLanguage language) => language == AppLanguage.zh ? zh : en;

  static final en = AppStrings(
    appName: 'CloudNews',
    tagline: 'Ultra-low latency HD video meetings powered by Tencent TRTC',
    switchLanguage: '中文',
    termsNotice: 'Joining indicates agreement with the Terms of Service & Privacy Policy',
    joinMeetingTitle: 'Join a Meeting',
    joinMeetingDesc: 'Enter the 9-digit meeting code to join instantly. No account needed.',
    meetingCodeLabel: 'Meeting Code',
    meetingCodeHint: 'e.g. 849-210-994',
    nextStepBtn: 'Continue',
    roomValidating: 'Validating meeting...',
    roomNotFound: 'Meeting not found or has ended',
    inputRequiredError: 'Please enter a valid 9-digit meeting code or link',
    hostPrompt: 'Authorized host?',
    hostSignInLink: 'Host Sign In',
    lobbyTitle: 'Almost Ready',
    lobbyDesc: 'Confirm your display name and device preferences',
    linkDetectedBadge: 'Invite link',
    roomPrefix: 'Meeting',
    displayNameLabel: 'Your Display Name',
    displayNameHint: 'e.g. Alex Morgan',
    nameRequiredError: 'Please enter your name to display in the meeting',
    micOn: 'Mic On',
    micOff: 'Mic Off',
    videoOn: 'Video On',
    videoOff: 'Video Off',
    cameraReady: 'Camera will turn on when you join',
    cameraOffNotice: 'Camera is turned off',
    enterRoomBtn: 'Join Meeting Room',
    joiningNotice: 'Joining meeting room...',
    hostLoginTitle: 'Host Sign In',
    hostLoginDesc: 'Enter the username and password from your administrator',
    usernameLabel: 'Username',
    usernameHint: 'e.g. host01',
    passwordLabel: 'Password',
    passwordHint: '••••••••••••',
    signInButton: 'Sign In',
    authMissingFields: 'Please provide both username and password',
    welcomeGreeting: 'Welcome,',
    signOut: 'Sign Out',
    instantMeetingTitle: 'New Instant Meeting',
    instantMeetingDesc:
        'Create an instant room with multi-party HD video, audio, and screen sharing powered by Tencent TRTC.',
    startInstantMeetingBtn: 'Start Meeting Now',
    trtcStatusTitle: 'Tencent RTC Engine Active',
    trtcStatusDesc: 'Hardware-accelerated echo cancellation, noise suppression and low-latency routing are on.',
    meetingTitleFor: (host) => "$host's Meeting",
    permissionDenied: 'Camera or microphone permission was denied. You can enable it later in Settings.',
    roomLoginFailed: 'Could not connect to the meeting service. Please try again.',
    switchCamera: 'Switch Camera',
    speakerOn: 'Speaker',
    earpieceOn: 'Earpiece',
    startScreenShare: 'Share Screen',
    stopScreenShare: 'Stop Share',
    screenShareActive: 'Sharing Screen',
    otherUserSharingScreen: (name) => '$name is currently sharing the screen.',
    leaveMeeting: 'Leave Meeting',
    endMeetingForAll: 'End Meeting for All',
    confirmLeave: 'Are you sure you want to leave this meeting?',
    confirmEnd: 'Are you sure you want to end this meeting for all participants?',
    cancel: 'Cancel',
    copyMeetingCode: 'Copy Meeting Code',
    codeCopied: 'Meeting code copied to clipboard',
    membersTitle: 'Participants',
    meBadge: 'Me',
    hostBadge: 'Host',
    hostEndedMeetingNotice: 'This meeting was ended by the host',
    soloTimeoutNotice: 'Meeting ended automatically due to inactivity',
    transferHostTitle: 'Assign New Host',
    transferHostSubtitle: 'Please select a participant to become the new host before you leave:',
    transferAndLeave: 'Transfer & Leave',
    youAreNowHost: 'You are now the host of this meeting',
    aloneInMeeting: 'You are the only person in the meeting. Leaving will end the meeting.',
    leaveAndEnd: 'Leave & End',
    chatTitle: 'Meeting Chat',
    typeMessageHint: 'Type a message...',
    sendBtn: 'Send',
    attachPhoto: 'Send Photo',
    attachFile: 'Send Document',
    uploadingFile: 'Uploading...',
    fileSizeLimitExceeded: 'File size cannot exceed 15MB',
    downloadFile: 'Download',
    downloading: 'Downloading...',
    downloaded: 'Downloaded',
    openFile: 'Open File',
    fileSavedNotice: 'Saved to Downloads',
    openInGallery: 'Open in Media Viewer',
    activeMeetingOngoingTitle: 'Active Meeting Ongoing',
    activeMeetingOngoingDesc: (code) =>
        'You already have an active meeting ($code). A host can only conduct one meeting at a time.',
    rejoinMeetingBtn: 'Rejoin Meeting',
    endPreviousAndStartBtn: 'End Previous & Start New',
  );

  static final zh = AppStrings(
    appName: '云新闻',
    tagline: '基于腾讯云 TRTC 的极速高清音视频会议',
    switchLanguage: 'English',
    termsNotice: '登录或加入即代表同意《用户服务协议》与《隐私保护指引》',
    joinMeetingTitle: '加入会议',
    joinMeetingDesc: '输入9位会议号，一键即时入会（无需注册）',
    meetingCodeLabel: '会议号',
    meetingCodeHint: '例如：849-210-994',
    nextStepBtn: '下一步',
    roomValidating: '正在验证会议号...',
    roomNotFound: '会议号不存在或已结束',
    inputRequiredError: '请输入有效的会议号或链接',
    hostPrompt: '拥有主持人账号？',
    hostSignInLink: '主持人登录',
    lobbyTitle: '准备就绪',
    lobbyDesc: '确认您的参会称呼与音视频设备设置',
    linkDetectedBadge: '邀请链接',
    roomPrefix: '会议号',
    displayNameLabel: '您的入会称呼',
    displayNameHint: '例如：张经理',
    nameRequiredError: '请输入入会昵称',
    micOn: '麦克风 已开',
    micOff: '麦克风 已关',
    videoOn: '摄像头 已开',
    videoOff: '摄像头 已关',
    cameraReady: '入会后将自动开启摄像头',
    cameraOffNotice: '已关闭摄像头',
    enterRoomBtn: '进入会议室',
    joiningNotice: '正在安全进入会议室...',
    hostLoginTitle: '主持人登录',
    hostLoginDesc: '请输入管理员分配的用户名和密码',
    usernameLabel: '用户名',
    usernameHint: '例如 host01',
    passwordLabel: '登录密码',
    passwordHint: '请输入密码',
    signInButton: '登 录',
    authMissingFields: '请输入用户名和密码',
    welcomeGreeting: '您好，',
    signOut: '退出登录',
    instantMeetingTitle: '发起快速会议',
    instantMeetingDesc: '一键创建高清多方音视频会议室，支持屏幕共享与腾讯云 TRTC 低延迟全球网络。',
    startInstantMeetingBtn: '立即开始会议',
    trtcStatusTitle: '腾讯 TRTC 引擎已就绪',
    trtcStatusDesc: '硬件级回声消除、智能降噪与低延迟网络已启动。',
    meetingTitleFor: (host) => '$host 的会议',
    permissionDenied: '摄像头或麦克风权限被拒绝，您可以稍后在系统设置中开启。',
    roomLoginFailed: '无法连接会议服务，请重试。',
    switchCamera: '翻转摄像头',
    speakerOn: '扬声器',
    earpieceOn: '听筒',
    startScreenShare: '共享屏幕',
    stopScreenShare: '停止共享',
    screenShareActive: '正在共享屏幕',
    otherUserSharingScreen: (name) => '$name 目前正在共享屏幕',
    leaveMeeting: '离开会议',
    endMeetingForAll: '结束全体会议',
    confirmLeave: '确定离开当前会议吗？',
    confirmEnd: '确定结束全体会议吗？所有参会者将被移出房间。',
    cancel: '取消',
    copyMeetingCode: '复制会议号',
    codeCopied: '会议号已复制到剪贴板',
    membersTitle: '参会成员',
    meBadge: '我',
    hostBadge: '主持人',
    hostEndedMeetingNotice: '主持人已结束本次会议',
    soloTimeoutNotice: '由于长时间无其他参会者，会议已自动结束',
    transferHostTitle: '转交主持人',
    transferHostSubtitle: '离开前请选择一位参会成员作为新主持人：',
    transferAndLeave: '转交并离开',
    youAreNowHost: '您已成为当前会议主持人',
    aloneInMeeting: '您是会议中唯一的成员，离开将结束此会议。',
    leaveAndEnd: '离开并结束',
    chatTitle: '会议聊天',
    typeMessageHint: '输入消息...',
    sendBtn: '发送',
    attachPhoto: '发送图片',
    attachFile: '发送文件',
    uploadingFile: '正在上传...',
    fileSizeLimitExceeded: '文件不能超过 15MB',
    downloadFile: '下载',
    downloading: '正在下载...',
    downloaded: '已下载',
    openFile: '打开文件',
    fileSavedNotice: '已保存至下载目录',
    openInGallery: '在媒体查看器中打开',
    activeMeetingOngoingTitle: '已有正在进行的会议',
    activeMeetingOngoingDesc: (code) =>
        '您已有一个正在进行的会议（$code）。主持人同一时间只能主持一个会议。',
    rejoinMeetingBtn: '重新加入会议',
    endPreviousAndStartBtn: '结束原会议并创建新会议',
  );
}
