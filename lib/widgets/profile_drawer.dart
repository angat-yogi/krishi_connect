import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  UserRole? _selectedRole;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.read<UserProfile?>();
    if (profile != null) {
      final newText = profile.displayName ?? '';
      if (_displayNameController.text != newText) {
        _displayNameController.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
      if (!_isSaving && profile.role != _selectedRole) {
        _selectedRole = profile.role;
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<UserProfile?>();
    if (profile == null) return;

    final authService = context.read<AuthService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      final newName = _displayNameController.text.trim();
      if (newName != profile.displayName && newName.isNotEmpty) {
        await authService.updateDisplayName(newName);
      }

      if (_selectedRole != null && _selectedRole != profile.role) {
        await authService.updateUserRole(_selectedRole!);
      }

      messenger.showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfile?>();
    final authService = context.read<AuthService>();

    return Drawer(
      child: SafeArea(
        child: profile == null
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        profileDisplayLabel(profile),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      subtitle: Text(
                        profileRoleLabel(profile),
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[700]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 50) {
                          return 'Please keep the name under 50 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: profile.email,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Role',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<UserRole>(
                      value: UserRole.farmer,
                      groupValue: _selectedRole,
                      onChanged: (value) => setState(() {
                        _selectedRole = value;
                      }),
                      title: const Text('Farmer'),
                    ),
                    RadioListTile<UserRole>(
                      value: UserRole.shopkeeper,
                      groupValue: _selectedRole,
                      onChanged: (value) => setState(() {
                        _selectedRole = value;
                      }),
                      title: const Text('Shopkeeper'),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save changes'),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).maybePop();
                        await authService.signOut();
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Log out'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

String profileDisplayLabel(UserProfile profile) {
  return profile.displayName?.isNotEmpty == true
      ? profile.displayName!
      : profile.email;
}

String profileRoleLabel(UserProfile profile) {
  return profile.role?.label ?? 'Role not set';
}

String profileHeaderLabel(UserProfile profile) {
  final name = profileDisplayLabel(profile);
  final role = profile.role?.label ?? 'Set role';
  return '$name ($role)';
}
