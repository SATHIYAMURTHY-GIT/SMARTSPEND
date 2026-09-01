import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/user_avatar_widget.dart';
import '../../models/user_profile.dart';
import '../../providers/authentication_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'notification_settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _isSavingName = false;
  bool _isDeletingAccount = false;
  String? _initializedProfileUserId;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _syncControllerWithProfile(UserProfile? profile, String? userId) {
    if (userId != null && _initializedProfileUserId != userId) {
      _initializedProfileUserId = userId;
      if (profile?.displayName != null) {
        _nameController.text = profile!.displayName!;
      }
    }
  }

  Future<void> _saveUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final newName = _nameController.text.trim();
    setState(() => _isSavingName = true);

    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateProfile(displayName: newName);

      _nameFocusNode.unfocus();
      if (mounted) {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update name: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  Future<void> _selectAvatar(AppAvatar avatar) async {
    try {
      await ref
          .read(userProfileRepositoryProvider)
          .updateProfile(avatar: avatar.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${avatar.label} avatar selected'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update avatar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final colors = Theme.of(context).colorScheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete your account?'),
          content: const Text(
            'This action is permanent and cannot be undone.\n\n'
            'All of your expenses, budgets, profile information, and application settings will be permanently erased.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);

    try {
      debugPrint('[AccountDeletion UI] Step 1: User confirmed deletion');
      debugPrint('[AccountDeletion UI] Step 2: Canceling all notifications');
      await ref.read(notificationServiceProvider).cancelAll();
      debugPrint('[AccountDeletion UI] Step 3: Calling deleteAccount()');
      await ref.read(authControllerProvider).deleteAccount();
      debugPrint('[AccountDeletion UI] Step 4: Account deletion completed successfully');
    } catch (e, stack) {
      debugPrint('[AccountDeletion UI] Error during account deletion: $e');
      debugPrint('[AccountDeletion UI] Stack trace: $stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: $e'),
            backgroundColor: colors.error,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeletingAccount = false);
      }
    }
  }

  String _themeModeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light mode active';
      case ThemeMode.dark:
        return 'Dark mode active';
      case ThemeMode.system:
        return 'Follows your device theme';
    }
  }

  IconData _themeModeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = ref.watch(authStateProvider).value;
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;
    final currentThemeMode = ref.watch(themeModeProvider);

    _syncControllerWithProfile(profile, user?.uid);

    final selectedAvatar = AppAvatar.fromId(profile?.avatar);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Overview Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      UserAvatarWidget(
                        avatarId: profile?.avatar,
                        radius: 28,
                        showBorder: true,
                        borderColor: colors.primary,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.safeDisplayName ?? 'SmartSpend User',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? 'Signed-in account',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Choose Avatar Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose avatar',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: AppAvatar.values.map((avatar) {
                            final isSelected = avatar == selectedAvatar;
                            return Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _selectAvatar(avatar),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primaryContainer.withValues(alpha: 0.35)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Stack(
                                        alignment: Alignment.bottomRight,
                                        children: [
                                          UserAvatarWidget(
                                            avatarId: avatar.id,
                                            radius: 22,
                                          ),
                                          if (isSelected)
                                            Container(
                                              decoration: BoxDecoration(
                                                color: colors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              padding: const EdgeInsets.all(2),
                                              child: Icon(
                                                Icons.check,
                                                size: 10,
                                                color: colors.onPrimary,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        avatar.label,
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? colors.primary
                                              : colors.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Username / Edit Name Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your name',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                decoration: InputDecoration(
                                  hintText: 'Enter your name',
                                  prefixIcon: const Icon(Icons.badge_outlined),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a valid name';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: _isSavingName ? null : _saveUsername,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              icon: _isSavingName
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Appearance / Preferences
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: Icon(_themeModeIcon(currentThemeMode)),
                      title: const Text('Appearance'),
                      subtitle: Text(_themeModeSubtitle(currentThemeMode)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (selected) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(selected.first);
                          },
                        ),
                      ),
                    ),
                    Divider(height: 1, color: colors.outlineVariant),
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: const Text('Notifications'),
                      subtitle: const Text('Budgets, reminders & alerts'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Account / Danger Zone Card
              Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(
                        'Account',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: colors.error,
                      ),
                      title: Text(
                        'Delete account',
                        style: TextStyle(
                          color: colors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Permanently delete your account and all financial data',
                      ),
                      trailing: _isDeletingAccount
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right,
                              color: colors.error,
                            ),
                      onTap: _isDeletingAccount ? null : _confirmDeleteAccount,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Sign out
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sign out'),
                  subtitle: Text(user?.email ?? 'Sign out of this account'),
                  onTap: _isDeletingAccount
                      ? null
                      : () => ref.read(authControllerProvider).signOut(),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'SmartSpend is ready for your preferences.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}