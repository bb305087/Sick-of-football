import 'dart:convert';
import 'dart:typed_data';

class ProfilePhotoModel {
  final Uint8List bytes;
  final String contentType;

  const ProfilePhotoModel({
    required this.bytes,
    required this.contentType,
  });

  factory ProfilePhotoModel.fromJson(Map<String, dynamic> json) {
    final encoded = json['content'];
    final contentType = json['content_type'];
    if (encoded is! String || contentType is! String) {
      throw const FormatException('Nieprawidłowe dane zdjęcia profilowego.');
    }
    return ProfilePhotoModel(
      bytes: base64Decode(encoded),
      contentType: contentType,
    );
  }
}
