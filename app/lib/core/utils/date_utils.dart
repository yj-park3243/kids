import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static int calculateAgeMonths(int birthYear, int birthMonth) {
    final now = DateTime.now();
    return (now.year - birthYear) * 12 + (now.month - birthMonth);
  }

  static String formatAgeMonths(int months) {
    if (months < 0) return '출산예정';
    if (months < 12) return '$months개월';
    final years = months ~/ 12;
    final remainMonths = months % 12;
    if (remainMonths == 0) return '$years세';
    return '$years세 $remainMonths개월';
  }

  static String formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);

    final diff = targetDate.difference(today).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '내일';
    if (diff == 2) return '모레';
    if (diff < 7) return '$diff일 후';

    return DateFormat('M월 d일 (E)', 'ko').format(date);
  }

  static String formatTime(String timeStr) {
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  static String formatDateTime(String dateStr, String timeStr) {
    return '${formatDate(dateStr)} ${formatTime(timeStr)}';
  }

  static String formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';

    return DateFormat('M/d').format(dateTime);
  }

  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (msgDate == today) {
      return DateFormat('a h:mm', 'ko').format(dateTime);
    }

    final diff = today.difference(msgDate).inDays;
    if (diff == 1) return '어제';
    if (diff < 7) return DateFormat('E', 'ko').format(dateTime);

    return DateFormat('M/d').format(dateTime);
  }

  static String formatCostDisplay(int cost) {
    if (cost == 0) return '무료';
    final formatter = NumberFormat('#,###');
    final formatted = formatter.format(cost);
    return '$formatted원';
  }
}
