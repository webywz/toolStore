import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.onLogin,
    required this.onRegister,
    required this.onResetPassword,
  });

  final Future<void> Function({
    required String account,
    required String password,
  })
  onLogin;
  final Future<void> Function({
    required String account,
    required String password,
    required String nickname,
  })
  onRegister;
  final Future<void> Function({
    required String account,
    required String newPassword,
  })
  onResetPassword;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _submitting = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10244E), Color(0xFF2E5DA8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '船用五金 AI 工具',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '登录后可同步收藏、历史记录、识别反馈和知识库管理权限。',
                        style: TextStyle(color: Colors.white70, fontSize: 15),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  tabs: [
                    Tab(text: '登录'),
                    Tab(text: '注册'),
                    Tab(text: '找回密码'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _LoginTab(
                      submitting: _submitting,
                      onSubmit: ({required account, required password}) {
                        return _run(
                          () => widget.onLogin(
                            account: account,
                            password: password,
                          ),
                        );
                      },
                    ),
                    _RegisterTab(
                      submitting: _submitting,
                      onSubmit:
                          ({
                            required account,
                            required password,
                            required nickname,
                          }) {
                            return _run(
                              () => widget.onRegister(
                                account: account,
                                password: password,
                                nickname: nickname,
                              ),
                            );
                          },
                    ),
                    _ResetPasswordTab(
                      submitting: _submitting,
                      onSubmit: ({required account, required newPassword}) {
                        return _run(
                          () => widget.onResetPassword(
                            account: account,
                            newPassword: newPassword,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginTab extends StatefulWidget {
  const _LoginTab({required this.submitting, required this.onSubmit});

  final bool submitting;
  final Future<void> Function({
    required String account,
    required String password,
  })
  onSubmit;

  @override
  State<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends State<_LoginTab> {
  final _accountController = TextEditingController(text: '13800138000');
  final _passwordController = TextEditingController(text: '123456');

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      children: [
        TextField(
          controller: _accountController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '账号'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.submitting
                ? null
                : () => widget.onSubmit(
                    account: _accountController.text.trim(),
                    password: _passwordController.text,
                  ),
            child: Text(widget.submitting ? '登录中...' : '登录'),
          ),
        ),
      ],
    );
  }
}

class _RegisterTab extends StatefulWidget {
  const _RegisterTab({required this.submitting, required this.onSubmit});

  final bool submitting;
  final Future<void> Function({
    required String account,
    required String password,
    required String nickname,
  })
  onSubmit;

  @override
  State<_RegisterTab> createState() => _RegisterTabState();
}

class _RegisterTabState extends State<_RegisterTab> {
  final _nicknameController = TextEditingController();
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _nicknameController.dispose();
    _accountController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次输入的密码不一致。')));
      return;
    }
    await widget.onSubmit(
      account: _accountController.text.trim(),
      password: _passwordController.text,
      nickname: _nicknameController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      children: [
        TextField(
          controller: _nicknameController,
          decoration: const InputDecoration(labelText: '昵称'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _accountController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: '账号',
            hintText: '建议使用英文、数字或下划线',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '确认密码'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: Text(widget.submitting ? '注册中...' : '注册并登录'),
          ),
        ),
      ],
    );
  }
}

class _ResetPasswordTab extends StatefulWidget {
  const _ResetPasswordTab({required this.submitting, required this.onSubmit});

  final bool submitting;
  final Future<void> Function({
    required String account,
    required String newPassword,
  })
  onSubmit;

  @override
  State<_ResetPasswordTab> createState() => _ResetPasswordTabState();
}

class _ResetPasswordTabState extends State<_ResetPasswordTab> {
  final _accountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('两次输入的新密码不一致。')));
      return;
    }
    await widget.onSubmit(
      account: _accountController.text.trim(),
      newPassword: _passwordController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('密码已重置，请使用新密码登录。')));
  }

  @override
  Widget build(BuildContext context) {
    return _AuthFormScaffold(
      children: [
        TextField(
          controller: _accountController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: '账号'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '新密码'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          obscureText: true,
          decoration: const InputDecoration(labelText: '确认新密码'),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: Text(widget.submitting ? '提交中...' : '重置密码'),
          ),
        ),
      ],
    );
  }
}

class _AuthFormScaffold extends StatelessWidget {
  const _AuthFormScaffold({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
