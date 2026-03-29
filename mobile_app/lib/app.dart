import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/app_models.dart';
import 'screens/auth_screen.dart';
import 'screens/root_shell.dart';
import 'services/backend_api.dart';
import 'theme/app_theme.dart';

class MarineHardwareApp extends StatefulWidget {
  const MarineHardwareApp({super.key});

  @override
  State<MarineHardwareApp> createState() => _MarineHardwareAppState();
}

class _MarineHardwareAppState extends State<MarineHardwareApp> {
  static const _tokenKey = 'tool_store_auth_token';

  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final BackendApi _api;

  AppUser? _currentUser;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _api = BackendApi(onUnauthorized: _handleUnauthorized);
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() => _initializing = false);
      return;
    }
    try {
      _api.restoreToken(token);
      final user = await _api.fetchCurrentUser();
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _initializing = false;
      });
    } catch (_) {
      await _clearSession(showMessage: false);
      if (!mounted) return;
      setState(() => _initializing = false);
    }
  }

  Future<void> _persistCurrentToken() async {
    final token = _api.currentToken;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_tokenKey);
      return;
    }
    await prefs.setString(_tokenKey, token);
  }

  Future<void> _clearSession({required bool showMessage}) async {
    _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    if (!mounted) return;
    setState(() => _currentUser = null);
    if (showMessage) {
      _messengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('登录状态已失效，请重新登录。')),
      );
    }
  }

  void _handleUnauthorized() {
    _clearSession(showMessage: true);
  }

  Future<void> _completeAuthenticatedSession() async {
    final user = await _api.fetchCurrentUser();
    await _persistCurrentToken();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  Future<void> _login({
    required String account,
    required String password,
  }) async {
    await _api.login(account: account, password: password);
    await _completeAuthenticatedSession();
  }

  Future<void> _register({
    required String account,
    required String password,
    required String nickname,
  }) async {
    await _api.register(
      account: account,
      password: password,
      nickname: nickname,
    );
    await _completeAuthenticatedSession();
  }

  Future<void> _resetPassword({
    required String account,
    required String newPassword,
  }) async {
    await _api.resetPassword(account: account, newPassword: newPassword);
  }

  Future<void> _logout() async {
    await _clearSession(showMessage: false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '船用五金 AI 工具',
      theme: AppTheme.lightTheme,
      scaffoldMessengerKey: _messengerKey,
      home: _initializing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _currentUser == null
          ? AuthScreen(
              onLogin: _login,
              onRegister: _register,
              onResetPassword: _resetPassword,
            )
          : RootShell(api: _api, currentUser: _currentUser!, onLogout: _logout),
    );
  }
}
