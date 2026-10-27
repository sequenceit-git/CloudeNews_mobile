import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/env.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client for the CloudNews server (`cloudmeet_web/server`). UserSigs are
/// always issued by the server; the app never holds the TRTC secret key.
class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  static const _timeout = Duration(seconds: 12);

  final http.Client _client = http.Client();
  String? _token;

  bool get isHostSignedIn => _token != null;

  void signOut() => _token = null;

  Future<HostUser> hostLogin(String username, String password) async {
    final data = await _send(
      'POST',
      '/auth/host/login',
      body: {'username': username.trim(), 'password': password.trim()},
      fallbackError: '登录失败 / Login failed',
    );
    _token = data['token'] as String?;
    return HostUser.fromJson(Map<String, dynamic>.from(data['host'] as Map));
  }

  Future<MeetingTicket> createInstantMeeting(String title) async {
    final data = await _send(
      'POST',
      '/meetings/instant',
      body: {'title': title},
      auth: true,
      fallbackError: 'Failed to create meeting',
    );
    return MeetingTicket.fromJson(data);
  }

  Future<MeetingValidation> validateMeeting(String meetingCode) async {
    final data = await _send(
      'GET',
      '/meetings/${Uri.encodeComponent(meetingCode.trim())}/validate',
      acceptErrorBody: true,
      fallbackError: 'Meeting not found',
    );
    return MeetingValidation(valid: data['valid'] == true, reason: data['reason'] as String?);
  }

  Future<MeetingTicket> joinAsGuest(String meetingCode, String displayName) async {
    final data = await _send(
      'POST',
      '/meetings/${Uri.encodeComponent(meetingCode.trim())}/join',
      body: {'displayName': displayName.trim()},
      fallbackError: 'Failed to join meeting',
    );
    return MeetingTicket.fromJson(data);
  }

  /// Records that this person left. The server ends the meeting 5 minutes
  /// after the room becomes empty.
  Future<void> leaveMeeting(String meetingId, String userId) async {
    await _send(
      'POST',
      '/meetings/$meetingId/leave',
      body: {'userId': userId},
      fallbackError: 'Failed to leave meeting',
    );
  }

  Future<void> endMeeting(String meetingId) async {
    await _send(
      'POST',
      '/meetings/$meetingId/end',
      auth: true,
      fallbackError: 'Failed to end meeting',
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
    bool acceptErrorBody = false,
    required String fallbackError,
  }) async {
    final uri = Uri.parse('${Env.apiBaseUrl}$path');
    final headers = <String, String>{
      if (body != null) 'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };

    http.Response res;
    try {
      final request = method == 'GET'
          ? _client.get(uri, headers: headers)
          : _client.post(uri, headers: headers, body: body == null ? null : jsonEncode(body));
      res = await request.timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('网络请求超时，请检查网络连接 / Request timed out. Please check your network.');
    } on SocketException {
      throw const ApiException('无法连接到服务器，请检查网络连接 / Unable to connect to server.');
    } on http.ClientException {
      throw const ApiException('无法连接到服务器，请检查网络连接 / Unable to connect to server.');
    }

    Map<String, dynamic> data = const {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // Non-JSON body; handled by the status check below.
      }
    }

    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (!ok && !acceptErrorBody) {
      final message = data['error'] ?? data['message'];
      throw ApiException(message is String && message.isNotEmpty ? message : fallbackError,
          statusCode: res.statusCode);
    }
    return data;
  }
}
