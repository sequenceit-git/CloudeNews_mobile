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
  );
}
