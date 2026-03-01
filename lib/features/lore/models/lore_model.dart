class LoreEntry {
  const LoreEntry({
    required this.id,
    required this.title,
    required this.content,
    this.mediaPath,
    this.isVideo = false,
  });

  final String id;
  final String title;
  final String content;
  final String? mediaPath; // Path to video or audio asset
  final bool isVideo; // True if media is video, false if audio
}
