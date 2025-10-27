import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class ProfileDrawer extends StatefulWidget {
  const ProfileDrawer({super.key});

  @override
  State<ProfileDrawer> createState() => _ProfileDrawerState();
}

class _ProfileDrawerState extends State<ProfileDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _localPhoto;
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
      final newLocation = profile.location ?? '';
      if (_locationController.text != newLocation) {
        _locationController.value = TextEditingValue(
          text: newLocation,
          selection: TextSelection.collapsed(offset: newLocation.length),
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
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final result = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (result != null) {
      setState(() {
        _localPhoto = File(result.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final profile = context.read<UserProfile?>();
    if (profile == null) return;

    final authService = context.read<AuthService>();
    final storageService = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSaving = true);
    try {
      final newName = _displayNameController.text.trim();
      if (newName != profile.displayName && newName.isNotEmpty) {
        await authService.updateDisplayName(newName);
      }

      final location = _locationController.text.trim();
      if (location != profile.location && location.isNotEmpty) {
        await authService.updateLocation(location);
      }

      if (_selectedRole != null && _selectedRole != profile.role) {
        await authService.updateUserRole(_selectedRole!);
      }

      if (_localPhoto != null) {
        final url = await storageService.uploadProfilePhoto(
          file: _localPhoto!,
          uid: profile.uid,
        );
        if (url != null) {
          await authService.updatePhotoUrl(url);
          setState(() {
            _localPhoto = null;
          });
        }
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
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _isSaving ? null : _pickProfileImage,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 96,
                                width: 96,
                                color: Colors.grey[200],
                                child: _localPhoto != null
                                    ? Image.file(
                                        _localPhoto!,
                                        fit: BoxFit.cover,
                                      )
                                    : (profile.photoUrl != null &&
                                            profile.photoUrl!.isNotEmpty)
                                        ? Image.network(
                                            profile.photoUrl!,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.photo_camera_outlined,
                                            size: 40,
                                          ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profileDisplayLabel(profile),
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            profileRoleLabel(profile),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[700]),
                          ),
                          if ((profile.location ?? '').isNotEmpty)
                            Text(
                              profile.location!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          TextButton(
                            onPressed: _isSaving ? null : _pickProfileImage,
                            child: const Text('Change photo'),
                          ),
                        ],
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Location is required';
                        }
                        return null;
                      },
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
