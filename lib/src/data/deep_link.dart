/// `nthcase-sample://item/{id}`: the one deep link every Mossgrove app answers (SPEC.md §5, Deep link).
abstract final class DeepLinks {
  static const scheme = 'nthcase-sample';
  static const itemHost = 'item';

  /// The item id as written in the link, or null when the link is not an item link. The id may be unknown or not a
  /// number; the item screen says so. Any other scheme, host or path is ignored.
  static String? itemId(Uri? uri) {
    if (uri == null || uri.scheme != scheme || uri.host != itemHost) return null;
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 1) return null;
    return segments.single;
  }

  static String forItem(int id) => '$scheme://$itemHost/$id';
}
