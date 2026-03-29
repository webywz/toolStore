import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_models.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenHistory,
    required this.onOpenFavorites,
    required this.onOpenKnowledgeAdmin,
    required this.onOpenAddCategory,
    required this.onOpenProductAdmin,
    required this.onUpdateProfile,
    required this.onUploadAvatar,
    required this.onChangePassword,
    required this.onLogout,
    required this.user,
    required this.onRefreshData,
  });

  final VoidCallback onOpenHistory;
  final VoidCallback onOpenFavorites;
  final VoidCallback onOpenKnowledgeAdmin;
  final VoidCallback onOpenAddCategory;
  final VoidCallback onOpenProductAdmin;
  final Future<void> Function({required String nickname, String? avatarUrl})
  onUpdateProfile;
  final Future<String?> Function({
    required List<int> fileBytes,
    required String filename,
    required String contentType,
  })
  onUploadAvatar;
  final Future<void> Function({
    required String oldPassword,
    required String newPassword,
  })
  onChangePassword;
  final Future<void> Function() onLogout;
  final AppUser? user;
  final Future<void> Function() onRefreshData;

  ImageProvider<Object>? _avatarProvider(String? avatarUrl) {
    final trimmed = avatarUrl?.trim() ?? '';
    if (trimmed.contains('oss.example.com')) {
      return null;
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return NetworkImage(trimmed);
    }
    return null;
  }

  Future<void> _openEditProfile(BuildContext context) async {
    final currentUser = user;
    if (currentUser == null) return;
    final nicknameController = TextEditingController(text: currentUser.nickname);
    final avatarController = TextEditingController(
      text: currentUser.avatarUrl ?? '',
    );
    final messenger = ScaffoldMessenger.of(context);
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var submitting = false;
        XFile? selectedAvatarFile;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final avatarPreview = selectedAvatarFile != null
                ? FileImage(File(selectedAvatarFile!.path))
                : _avatarProvider(avatarController.text);
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('编辑资料', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Center(
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: AppTheme.blue.withValues(alpha: 0.12),
                          backgroundImage: avatarPreview,
                          onBackgroundImageError: (
                            Object error,
                            StackTrace? stackTrace,
                          ) {},
                          child: avatarPreview == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: AppTheme.navy,
                                  size: 30,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 86,
                                  maxWidth: 1024,
                                );
                                if (picked == null) return;
                                setSheetState(() => selectedAvatarFile = picked);
                              },
                        icon: const Icon(Icons.photo_library_rounded),
                        label: Text(
                          selectedAvatarFile == null ? '选择头像图片' : '已选择新头像',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nicknameController,
                        decoration: const InputDecoration(labelText: '昵称'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: avatarController,
                        keyboardType: TextInputType.url,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: '头像 URL',
                          hintText: '可留空，例如 https://example.com/avatar.png',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '当前账号 ${currentUser.account}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: submitting
                              ? null
                              : () async {
                                  final nickname = nicknameController.text.trim();
                                  final avatarUrl = avatarController.text.trim();
                                  if (nickname.isEmpty) {
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('昵称不能为空。')),
                                    );
                                    return;
                                  }
                                  if (avatarUrl.isNotEmpty &&
                                      !avatarUrl.startsWith('http://') &&
                                      !avatarUrl.startsWith('https://') &&
                                      !avatarUrl.startsWith('/')) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('头像 URL 需以 http://、https:// 或 / 开头。'),
                                      ),
                                    );
                                    return;
                                  }
                                  setSheetState(() => submitting = true);
                                  try {
                                    var avatarUrl = avatarController.text.trim();
                                    if (selectedAvatarFile != null) {
                                      avatarUrl =
                                          (await onUploadAvatar(
                                                fileBytes: await selectedAvatarFile!
                                                    .readAsBytes(),
                                                filename: selectedAvatarFile!.name,
                                                contentType: 'image/jpeg',
                                              )) ??
                                              avatarUrl;
                                    }
                                    await onUpdateProfile(
                                      nickname: nickname,
                                      avatarUrl: avatarUrl.isEmpty ? null : avatarUrl,
                                    );
                                    if (sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(content: Text('资料已更新')),
                                    );
                                  } catch (error) {
                                    setSheetState(() => submitting = false);
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          error.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                },
                          child: Text(submitting ? '保存中...' : '保存资料'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nicknameController.dispose();
    avatarController.dispose();
  }

  Future<void> _openChangePassword(BuildContext context) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var submitting = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('修改密码', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextField(
                      controller: oldController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '原密码'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '新密码'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: '确认新密码'),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submitting
                            ? null
                            : () async {
                                if (newController.text !=
                                    confirmController.text) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('两次输入的新密码不一致。'),
                                    ),
                                  );
                                  return;
                                }
                                setSheetState(() => submitting = true);
                                try {
                                  await onChangePassword(
                                    oldPassword: oldController.text,
                                    newPassword: newController.text,
                                  );
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('密码修改成功')),
                                  );
                                } catch (error) {
                                  setSheetState(() => submitting = false);
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                          'Exception: ',
                                          '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(submitting ? '提交中...' : '确认修改'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    oldController.dispose();
    newController.dispose();
    confirmController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _avatarProvider(user?.avatarUrl);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.navy, Color(0xFF365FC4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0x26FFFFFF),
                  backgroundImage: avatarProvider,
                  onBackgroundImageError: (
                    Object error,
                    StackTrace? stackTrace,
                  ) {},
                  child: avatarProvider == null
                      ? const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 28,
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  user?.nickname ?? '现场维修账号',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user == null ? '当前未登录。' : '账号 ${user!.account}，当前已连接本地后端。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              await onRefreshData();
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('数据已刷新')));
              }
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('刷新后端数据'),
          ),
          const SizedBox(height: 18),
          _MenuTile(
            icon: Icons.edit_rounded,
            color: AppTheme.navy,
            title: '编辑资料',
            subtitle: '修改昵称和头像地址',
            onTap: () => _openEditProfile(context),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.history_rounded,
            color: AppTheme.blue,
            title: '识别与问答历史',
            subtitle: '回查最近结果和提问',
            onTap: onOpenHistory,
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.bookmark_rounded,
            color: AppTheme.amber,
            title: '我的收藏',
            subtitle: '快速回到高频配件',
            onTap: onOpenFavorites,
          ),
          const SizedBox(height: 12),
          if (user?.isAdmin ?? false) ...[
            _MenuTile(
              icon: Icons.auto_stories_rounded,
              color: AppTheme.navy,
              title: '知识库管理',
              subtitle: '上传、编辑、删除并重建 RAG 片段',
              onTap: onOpenKnowledgeAdmin,
            ),
            const SizedBox(height: 12),
          ],
          if (user?.isAdmin ?? false) ...[
            _MenuTile(
              icon: Icons.category_rounded,
              color: AppTheme.blue,
              title: '添加分类',
              subtitle: '内部维护入口，新增后端分类',
              onTap: onOpenAddCategory,
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.inventory_2_rounded,
              color: AppTheme.mint,
              title: '商品管理',
              subtitle: '新增、编辑、删除商品信息',
              onTap: onOpenProductAdmin,
            ),
            const SizedBox(height: 12),
          ],
          _MenuTile(
            icon: Icons.lock_reset_rounded,
            color: AppTheme.navy,
            title: '修改密码',
            subtitle: '修改当前账号登录密码',
            onTap: () => _openChangePassword(context),
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.flag_rounded,
            color: AppTheme.coral,
            title: '错误反馈',
            subtitle: '识别不准或回答有误时提交',
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '反馈已接通',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '拍照识别页已经可以提交纠错反馈，后续还可以继续补问答评分与运营看板。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.logout_rounded,
            color: AppTheme.coral,
            title: '退出登录',
            subtitle: '清除本地登录状态并返回登录页',
            onTap: () async {
              await onLogout();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
