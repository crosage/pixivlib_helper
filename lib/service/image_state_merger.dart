import 'package:tagselector/model/image_model.dart';

ImageModel mergeImageState(ImageModel base, ImageModel updated) {
  return base.copyWith(
    bookmarkCount: updated.bookmarkCount,
    isBookmarked: updated.isBookmarked,
    updatedAt: updated.updatedAt == 0 ? base.updatedAt : updated.updatedAt,
    needsRefresh: updated.needsRefresh,
  );
}

