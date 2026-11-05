import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class AddProfilePhotoScreen extends StatefulWidget {
  const AddProfilePhotoScreen({super.key});

  @override
  State<AddProfilePhotoScreen> createState() => _AddProfilePhotoScreenState();
}

class _AddProfilePhotoScreenState extends State<AddProfilePhotoScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedPhoto;
  bool _isPicking = false;

  Future<void> _pickPhoto(ImageSource source) async {
    if (_isPicking) return;

    setState(() => _isPicking = true);
    try {
      final status = await _requestPermission(source);

      if (!status.isGranted) {
        if (!mounted) return;
        await _showPermissionDeniedDialog(status);
        return;
      }

      final photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (photo == null || !mounted) return;

      setState(() => _selectedPhoto = File(photo.path));
    } on PlatformException {
      if (!mounted) return;
      _showMessage('Nie udało się wybrać zdjęcia. Spróbuj ponownie.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<PermissionStatus> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      return Permission.camera.request();
    }
    if (!Platform.isAndroid) return Permission.photos.request();

    final photosStatus = await Permission.photos.request();
    if (photosStatus.isGranted || photosStatus.isPermanentlyDenied) {
      return photosStatus;
    }
    return Permission.storage.request();
  }

  Future<void> _showPermissionDeniedDialog(PermissionStatus status) async {
    final permanentlyDenied = status.isPermanentlyDenied || status.isRestricted;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Brak dostępu do zdjęć'),
        content: Text(
          permanentlyDenied
              ? 'Dostęp został zablokowany. Włącz go w ustawieniach urządzenia, aby dodać zdjęcie profilowe.'
              : 'Zezwól aplikacji na dostęp do zdjęć, aby dodać zdjęcie profilowe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anuluj'),
          ),
          if (permanentlyDenied)
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await openAppSettings();
              },
              child: const Text('Otwórz ustawienia'),
            ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zdjęcie profilowe')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Dodaj zdjęcie profilowe',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Wybierz zdjęcie z urządzenia lub zrób nowe aparatem.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: CircleAvatar(
              radius: 96,
              backgroundImage: _selectedPhoto == null
                  ? null
                  : FileImage(_selectedPhoto!),
              child: _selectedPhoto == null
                  ? const Icon(Icons.person, size: 96)
                  : null,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _isPicking
                ? null
                : () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Wybierz z galerii'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isPicking ? null : () => _pickPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Zrób zdjęcie'),
          ),
          if (_isPicking) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_selectedPhoto != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_selectedPhoto),
              child: const Text('Ustaw zdjęcie'),
            ),
          ],
        ],
      ),
    );
  }
}
