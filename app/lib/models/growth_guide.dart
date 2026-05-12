import 'room.dart';

class GrowthGuide {
  final int ageMonth;
  final String title;
  final String summary;
  final String bodyMarkdown;
  final String? coverImage;
  final List<String> tags;
  final List<Room>? recommendedRooms;

  GrowthGuide({
    required this.ageMonth,
    required this.title,
    required this.summary,
    required this.bodyMarkdown,
    this.coverImage,
    this.tags = const [],
    this.recommendedRooms,
  });

  factory GrowthGuide.fromJson(Map<String, dynamic> json) {
    return GrowthGuide(
      ageMonth: json['ageMonth'] ?? 0,
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      bodyMarkdown: json['bodyMarkdown'] ?? '',
      coverImage: json['coverImage'],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      recommendedRooms: json['recommendedRooms'] != null
          ? (json['recommendedRooms'] as List)
              .map((e) => Room.fromJson(e))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'ageMonth': ageMonth,
        'title': title,
        'summary': summary,
        'bodyMarkdown': bodyMarkdown,
        'coverImage': coverImage,
        'tags': tags,
        'recommendedRooms': recommendedRooms,
      };
}
