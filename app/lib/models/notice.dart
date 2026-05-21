/// 공지사항 — 어드민에서 작성, 앱에 노출.
class Notice {
  final String id;
  final String title;
  final String content;
  final bool isPinned;
  final DateTime createdAt;

  const Notice({
    required this.id,
    required this.title,
    required this.content,
    this.isPinned = false,
    required this.createdAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
