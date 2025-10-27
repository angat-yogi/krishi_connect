import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../services/storage_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  static const String routeName = '/signup';

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  File? _profileImage;

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        _profileImage = File(result.path);
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();
      await authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        await authService.updateDisplayName(name);
      }
      final location = _locationController.text.trim();
      await authService.updateLocation(location);

      final user = FirebaseAuth.instance.currentUser;
      final storageService = context.read<StorageService>();
      if (user != null && _profileImage != null) {
        final url = await storageService.uploadProfilePhoto(
          file: _profileImage!,
          uid: user.uid,
        );
        if (url != null) {
          await authService.updatePhotoUrl(url);
        }
      }

      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Registration failed');
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Join KrishiConnect 🌱',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              SizedBox(height: 16.h),
              Text(
                'Create your account to start trading fresh produce.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 32.h),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _pickProfileImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 96,
                          width: 96,
                          color: Colors.grey[200],
                          child: _profileImage != null
                              ? Image.file(
                                  _profileImage!,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 40,
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: _isLoading ? null : _pickProfileImage,
                      child: const Text('Upload profile photo'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20.h),
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
              SizedBox(height: 32.h),
              FilledButton(
                onPressed: _isLoading ? null : _register,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
