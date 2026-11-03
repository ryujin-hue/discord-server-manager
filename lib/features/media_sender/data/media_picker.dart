import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/picked_media.dart';

/// Picks files on the device. The tests replace this with a fake.
abstract class MediaPicker {
  /// Images and videos, selected through the Android Photo Picker.
  Future<List<PickedMedia>> pickMedia();

  /// Any other file, selected through the system file browser.
  Future<List<PickedMedia>> pickFiles();
}

/// The picker backed by the platform.
class DeviceMediaPicker implements MediaPicker {
  DeviceMediaPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  @override
  Future<List<PickedMedia>> pickMedia() async {
    final picked = await _imagePicker.pickMultipleMedia();
    return _toMedia(picked);
  }

  @override
  Future<List<PickedMedia>> pickFiles() async {
    final picked = await FilePicker.pickFiles(type: FileType.any);
    final result = <PickedMedia>[];
    for (final file in picked) {
      final path = file.path;
      if (path == null) {
        continue;
      }
      result.add(
        await _describe(
          path: path,
          name: file.name,
          mimeType: mimeTypeForExtension(file.extension),
        ),
      );
    }
    return result;
  }

  Future<List<PickedMedia>> _toMedia(List<XFile> files) async {
    final result = <PickedMedia>[];
    for (final file in files) {
      result.add(
        await _describe(
          path: file.path,
          name: file.name,
          mimeType: file.mimeType,
        ),
      );
    }
    return result;
  }

  Future<PickedMedia> _describe({
    required String path,
    required String name,
    String? mimeType,
  }) async {
    var size = 0;
    var modifiedAt = DateTime.now();
    try {
      final file = File(path);
      if (await file.exists()) {
        size = await file.length();
        modifiedAt = await file.lastModified();
      }
    } on FileSystemException {
      size = 0;
    }
    return PickedMedia(
      path: path,
      name: name,
      sizeBytes: size,
      kind: MediaKind.fromName(name, mimeType),
      mimeType: mimeType ?? mimeTypeForExtension(extensionOf(name)),
      modifiedAt: modifiedAt,
    );
  }
}

String extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0 || dot == name.length - 1) {
    return '';
  }
  return name.substring(dot + 1).toLowerCase();
}

/// A small mime type table for the formats Discord accepts.
String? mimeTypeForExtension(String? extension) {
  switch (extension?.toLowerCase()) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'mp4':
      return 'video/mp4';
    case 'mov':
      return 'video/quicktime';
    case 'mkv':
      return 'video/x-matroska';
    case 'webm':
      return 'video/webm';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'zip':
      return 'application/zip';
    default:
      return null;
  }
}
