import 'package:image_picker/image_picker.dart';
import '../models/media_models.dart';

/// Picks photos for Lemon (DECISIONS 073), resized on the device to about
/// 1600 px so each stays well under the backend's 4 MB limit. Widget tests
/// pass a fake instead.
class PhotoPicker {
  static const maxSide = 1600.0;

  /// Photos the backend can take, at most [limit]; the rest are counted in
  /// [PhotoPickResult.skipped] (an unsupported type or still over 4 MB).
  Future<PhotoPickResult> pick({required int limit}) async {
    if (limit <= 0) return const PhotoPickResult([], 0);
    final files = await ImagePicker().pickMultiImage(
        maxWidth: maxSide, maxHeight: maxSide, imageQuality: 85, limit: limit > 1 ? limit : null);
    final photos = <PickedPhoto>[];
    var skipped = 0;
    for (final file in files) {
      if (photos.length >= limit) {
        skipped++;
        continue;
      }
      final mime = PickedPhoto.mimeFor(file.mimeType, file.name);
      final bytes = await file.readAsBytes();
      if (mime == null || bytes.isEmpty || bytes.length > PickedPhoto.maxBytes) {
        skipped++;
        continue;
      }
      photos.add(PickedPhoto(bytes: bytes, mime: mime, name: file.name));
    }
    return PhotoPickResult(photos, skipped);
  }
}

class PhotoPickResult {
  final List<PickedPhoto> photos;
  final int skipped;
  const PhotoPickResult(this.photos, this.skipped);
}
