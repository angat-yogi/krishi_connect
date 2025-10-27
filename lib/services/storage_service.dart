import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  Future<String?> uploadProfilePhoto({
    required File file,
    required String uid,
  }) async {
    final ref = _storage.ref('profile_photos/$uid${path.extension(file.path)}');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  Future<String?> uploadProductImage({
    required File file,
    required String farmerId,
  }) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
    final ref = _storage.ref('products/$farmerId/$fileName');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
