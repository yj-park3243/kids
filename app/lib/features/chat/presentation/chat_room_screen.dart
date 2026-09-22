import '../../../widgets/top_toast.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/network/api_error.dart';
import '../../../core/utils/date_utils.dart';
import '../../../models/chat_message.dart';
import '../../../widgets/design/avatar.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/location_picker_sheet.dart';
import '../../auth/providers/auth_provider.dart';
import '../../room/providers/room_detail_provider.dart';
import '../data/chat_repository.dart';
import '../providers/chat_provider.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String chatRoomId;

  const ChatRoomScreen({super.key, required this.chatRoomId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen>
    with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<ChatMessage> _messages = [];
  // 기록 로드 실패 — 빈 방("첫 메시지를 보내보세요")과 구분해 재시도를 보여준다.
  String? _historyError;
  // messageId -> userIds who've read it. 같은 유저 중복 차감을 방지.
  final Map<String, Set<String>> _readers = {};
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repo = ref.read(chatRepositoryProvider);
      final page = await repo.fetchMessages(widget.chatRoomId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(page.items);
        _readers.clear();
        _loadingHistory = false;
        _historyError = null;
      });
      _markReadIfAny();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingHistory = false;
        // 이미 메시지가 떠 있으면(재진입 보충 실패) 조용히 유지한다.
        if (_messages.isEmpty) {
          _historyError =
              apiErrorMessage(e, fallback: '대화 내용을 불러오지 못했어요');
        }
      });
    }
  }

  @override
  void deactivate() {
    // 이 방을 읽음 처리한 결과를 목록/하단 탭 배지에 반영.
    // dispose에서는 ref를 쓸 수 없어(Bad state 크래시) deactivate에서 수행.
    ref.invalidate(chatRoomsProvider);
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // 백그라운드: 소켓을 즉시 끊어 서버가 이 유저를 "보고 있음"으로
      // 오판해 채팅 푸시를 스킵하는 일이 없도록 한다.
      ref.read(chatRepositoryProvider).pauseSocket();
    } else if (state == AppLifecycleState.resumed) {
      ref.read(chatRepositoryProvider).resumeSocket();
      // 끊겨 있던 동안 놓친 메시지 보충 + 읽음 처리(_loadHistory 말미에 수행).
      _loadHistory();
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _messageController.clear();
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.chatRoomId, content: content);
    } catch (e) {
      if (!mounted) return;
      // 실패한 원문을 입력창에 되돌려 다시 타이핑하지 않게 한다.
      if (_messageController.text.trim().isEmpty) {
        _messageController.text = content;
        _messageController.selection =
            TextSelection.collapsed(offset: content.length);
      }
      showTopToast(context, apiErrorMessage(e, fallback: '메시지를 보내지 못했어요'),
          backgroundColor: AppColors.error);
    }
  }

  Future<void> _sendLocation(
      {required double lat, required double lng, String label = ''}) async {
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            widget.chatRoomId,
            content: jsonEncode({'lat': lat, 'lng': lng, 'label': label}),
            type: 'LOCATION',
          );
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, '위치 전송 실패: $e');
    }
  }

  /// 입력바 + 버튼 → 위치 시트. 내 현재 위치 / 지도에서 선택.
  Future<void> _showLocationSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.my_location_rounded,
                  color: AppColors.ink),
              title: Text('내 위치 전송', style: AppTextStyles.body1Bold),
              subtitle: Text('현재 있는 곳을 즉시 공유',
                  style: AppTextStyles.caption),
              onTap: () => Navigator.pop(context, 'CURRENT'),
            ),
            const Divider(height: 1, color: AppColors.line),
            ListTile(
              leading: const Icon(Icons.map_rounded, color: AppColors.ink),
              title: Text('지도에서 선택', style: AppTextStyles.body1Bold),
              subtitle: Text('원하는 위치를 핀으로 정확히 지정',
                  style: AppTextStyles.caption),
              onTap: () => Navigator.pop(context, 'MAP'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;

    if (choice == 'CURRENT') {
      await _sendCurrentLocation();
    } else if (choice == 'MAP') {
      // 지도 시작 좌표 — 현재 위치(가능하면) → 서울시청 폴백.
      double initLat = 37.5665;
      double initLng = 126.978;
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 3),
            ),
          );
          initLat = pos.latitude;
          initLng = pos.longitude;
        }
      } catch (_) {/* 권한 거부 또는 타임아웃 — 폴백 좌표 사용 */}
      if (!mounted) return;
      final picked = await showLocationPickerSheet(
        context,
        initialLat: initLat,
        initialLng: initLng,
        title: '위치 선택',
      );
      if (picked != null) {
        await _sendLocation(
            lat: picked.lat, lng: picked.lng, label: picked.label);
      }
    }
  }

  Future<void> _sendCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        showTopToast(context, '위치 권한이 필요합니다.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      await _sendLocation(
          lat: pos.latitude, lng: pos.longitude, label: '내 위치');
    } catch (e) {
      if (!mounted) return;
      showTopToast(context, '현재 위치를 가져올 수 없어요: $e');
    }
  }

  /// 가장 최근 메시지 시점까지 읽음 처리. 화면을 보고 있는 동안 새 메시지가
  /// 들어오면 즉시 카운트가 -1 되도록.
  void _markReadIfAny() {
    if (_messages.isEmpty) return;
    final latest = _messages.first.createdAt;
    ref.read(chatRepositoryProvider).markRoomRead(
          widget.chatRoomId,
          asOf: latest,
        );
  }

  void _handleEvent(ChatRoomEvent event) {
    switch (event) {
      case ChatMessageEvent(:final message):
        if (_messages.any((m) => m.id == message.id)) return;
        setState(() => _messages.insert(0, message));
        _markReadIfAny();
      case ChatReadEvent(:final userId, :final lastReadAt):
        _applyReadReceipt(userId, lastReadAt);
    }
  }

  void _applyReadReceipt(String userId, DateTime lastReadAt) {
    bool changed = false;
    for (var i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.createdAt.isAfter(lastReadAt)) continue;
      if (msg.senderId == userId) continue;
      final readers = _readers.putIfAbsent(msg.id, () => <String>{});
      if (readers.add(userId)) {
        final next = (msg.unreadCount - 1).clamp(0, msg.unreadCount);
        if (next != msg.unreadCount) {
          _messages[i] = msg.copyWith(unreadCount: next);
          changed = true;
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';

    ref.listen<AsyncValue<ChatRoomEvent>>(
      chatRoomEventStreamProvider(widget.chatRoomId),
      (_, next) {
        final event = next.value;
        if (event != null) _handleEvent(event);
      },
    );

    // 채팅 목록 캐시에서 방 이름을 찾아 앱바 제목으로. 푸시 딥링크로
    // 바로 진입해 목록이 아직 없으면 '채팅' 폴백.
    final chatRooms = ref.watch(chatRoomsProvider).valueOrNull;
    var appBarTitle = '채팅';
    String? roomId;
    if (chatRooms != null) {
      for (final r in chatRooms) {
        if (r.id == widget.chatRoomId) {
          appBarTitle = r.roomTitle ?? appBarTitle;
          roomId = r.roomId;
          break;
        }
      }
    }
    // 채팅 목록 캐시가 아직 없어도(방 상세 → 채팅 경로) 방 상세 캐시엔 제목이 있다.
    // chatRoomId 는 roomId 와 같다(서버 createChatRoom 이 roomId 를 돌려준다).
    final cachedRoom = ref.watch(roomDetailProvider(roomId ?? widget.chatRoomId)).room;
    if (appBarTitle == '채팅' && cachedRoom != null) {
      appBarTitle = cachedRoom.title;
    }
    // 인원수는 이미 불러와 둔 방 상세에서만 읽는다. 이 화면이 새로 조회하지는 않는다.
    final memberCount = cachedRoom?.currentMembers;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.ink,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appBarTitle,
              style: AppTextStyles.screenTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (memberCount != null)
              Text('$memberCount명', style: AppTextStyles.caption),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.line),
          ),
        ),
      ),
      // 입력바가 홈 인디케이터 영역까지 흰 면으로 이어지도록 bottom SafeArea 는
      // 입력바가 직접 처리한다.
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _loadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.ink),
                    )
                  : _historyError != null && _messages.isEmpty
                      ? ErrorState(
                          message: _historyError!,
                          onRetry: () {
                            setState(() => _loadingHistory = true);
                            _loadHistory();
                          },
                        )
                      : _messages.isEmpty
                          ? Center(
                              child: Text(
                                '첫 번째 메시지를 보내보세요!',
                                style: AppTextStyles.body2
                                    .copyWith(color: AppColors.ink3),
                              ),
                            )
                          : _buildMessageList(userId),
            ),
            _InputBar(
              controller: _messageController,
              onSend: _sendMessage,
              onAddLocation: _showLocationSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(String userId) {
    // _messages는 최신이 [0]. 카카오톡 스타일을 위해선 같은 발신자/같은 분
    // 묶음의 "마지막" 발화에만 시간/카운트가 붙고, "첫" 발화 위에 아바타+이름이
    // 붙어야 한다. reverse:true 상태에서 인덱스 i와 양쪽 이웃을 비교한다.
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        if (message.isSystem) {
          return _SystemMessage(message: message);
        }
        // reverse:true이므로 [index+1]이 시각적으로 위쪽(=더 오래된) 메시지.
        final older = index + 1 < _messages.length ? _messages[index + 1] : null;
        final newer = index - 1 >= 0 ? _messages[index - 1] : null;

        final isMine = message.senderId == userId;
        final showDateHeader = older == null ||
            !_sameDay(older.createdAt.toLocal(), message.createdAt.toLocal()) ||
            older.isSystem;
        final showSenderHeader = !isMine &&
            (showDateHeader ||
                older.senderId != message.senderId ||
                older.isSystem);
        final showTimeFooter = newer == null ||
            newer.isSystem ||
            newer.senderId != message.senderId ||
            !_sameMinute(
                newer.createdAt.toLocal(), message.createdAt.toLocal()) ||
            !_sameDay(
                newer.createdAt.toLocal(), message.createdAt.toLocal());

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateHeader) _DateHeader(date: message.createdAt),
            _ChatBubble(
              message: message,
              isMine: isMine,
              showSenderHeader: showSenderHeader,
              showTimeFooter: showTimeFooter,
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _sameMinute(DateTime a, DateTime b) =>
      _sameDay(a, b) && a.hour == b.hour && a.minute == b.minute;
}

/// 날짜 구분 — 손글씨 한 줄 아래 형광펜 밑줄.
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.hi, width: 2),
            ),
          ),
          child: Text(
            AppDateUtils.formatChatDateHeader(date),
            style: AppTextStyles.stamp.copyWith(color: AppColors.ink2),
          ),
        ),
      ),
    );
  }
}

/// 입력바 — 흰 면 + 상단 헤어라인. ＋ / 입력 / 전송.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAddLocation;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onAddLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            key: const Key('btn-chat-add-location'),
            onTap: onAddLocation,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_location_alt_outlined,
                  color: AppColors.ink2, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fill,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TextField(
                key: const Key('input-chat-message'),
                controller: controller,
                style: AppTextStyles.body1,
                cursorColor: AppColors.ink,
                decoration: InputDecoration(
                  hintText: '메시지 보내기',
                  hintStyle:
                      AppTextStyles.body1.copyWith(color: AppColors.ink3),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('btn-chat-send'),
            onTap: onSend,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  final bool showSenderHeader;
  final bool showTimeFooter;

  const _ChatBubble({
    required this.message,
    required this.isMine,
    required this.showSenderHeader,
    required this.showTimeFooter,
  });

  /// 남 말풍선은 좌상단, 내 말풍선은 우상단이 꼬리(6).
  static BorderRadius radiusFor(bool isMine) => BorderRadius.only(
        topLeft: Radius.circular(isMine ? 16 : 6),
        topRight: Radius.circular(isMine ? 6 : 16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      );

  @override
  Widget build(BuildContext context) {
    final timeLabel =
        DateFormat('a h:mm', 'ko').format(message.createdAt.toLocal());
    final meta = _BubbleMeta(
      unreadCount: message.unreadCount,
      timeLabel: showTimeFooter ? timeLabel : null,
      alignRight: isMine,
    );

    return Padding(
      padding: EdgeInsets.only(top: showSenderHeader ? 12 : 3, bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            SizedBox(
              width: 32,
              child: showSenderHeader
                  ? InitialAvatar(
                      label: message.senderNickname,
                      size: 32,
                      tone: InitialAvatar.toneFor(message.senderId),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSenderHeader)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5, left: 2),
                    child: Text(
                      message.senderNickname,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink2,
                      ),
                    ),
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: isMine
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (isMine) ...[meta, const SizedBox(width: 6)],
                    Flexible(
                      child: message.isLocation
                          ? _LocationBubble(
                              message: message,
                              isMine: isMine,
                            )
                          : Container(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width * 0.65,
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? AppColors.ink
                                    : AppColors.surface,
                                borderRadius: radiusFor(isMine),
                                border: isMine
                                    ? null
                                    : Border.all(color: AppColors.line),
                              ),
                              child: Text(
                                message.content,
                                style: AppTextStyles.body1.copyWith(
                                  color:
                                      isMine ? Colors.white : AppColors.ink,
                                ),
                              ),
                            ),
                    ),
                    if (!isMine) ...[const SizedBox(width: 6), meta],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 카카오톡 식: 안 읽은 사람 수는 위, 전송 시각은 아래.
class _BubbleMeta extends StatelessWidget {
  final int unreadCount;
  final String? timeLabel;
  final bool alignRight;

  const _BubbleMeta({
    required this.unreadCount,
    required this.timeLabel,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      if (unreadCount > 0)
        Text(
          '$unreadCount',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.hiInk,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
        ),
      if (timeLabel != null)
        Padding(
          padding: EdgeInsets.only(top: unreadCount > 0 ? 2 : 0),
          child: Text(
            timeLabel!,
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.ink3,
              height: 1.0,
            ),
          ),
        ),
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment:
            alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// LOCATION 메시지 — 흰 카드 안 지도 썸네일 + 라벨. 탭하면 풀스크린 지도.
class _LocationBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _LocationBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final loc = message.location;
    if (loc == null) {
      // 잘못된 payload — 텍스트로 fallback.
      return Text('[위치]',
          style: AppTextStyles.body2
              .copyWith(color: isMine ? Colors.white : AppColors.ink2));
    }
    final radius = _ChatBubble.radiusFor(isMine);
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => _LocationFullscreen(
            lat: loc.lat,
            lng: loc.lng,
            label: loc.label,
          ),
        ),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: radius,
          border: Border.all(color: AppColors.line),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 130,
                child: ColoredBox(
                  color: AppColors.sky,
                  child: AbsorbPointer(
                    child: NaverMap(
                      options: NaverMapViewOptions(
                        initialCameraPosition: NCameraPosition(
                          target: NLatLng(loc.lat, loc.lng),
                          zoom: 15,
                        ),
                        scrollGesturesEnable: false,
                        zoomGesturesEnable: false,
                        tiltGesturesEnable: false,
                        rotationGesturesEnable: false,
                        logoClickEnable: false,
                      ),
                      onMapReady: (controller) {
                        controller.addOverlay(
                          NMarker(
                              id: 'msg_${message.id}',
                              position: NLatLng(loc.lat, loc.lng)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (loc.label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                  child: Text(
                    loc.label,
                    style: AppTextStyles.body1.copyWith(fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationFullscreen extends StatelessWidget {
  const _LocationFullscreen(
      {required this.lat, required this.lng, required this.label});
  final double lat;
  final double lng;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(label.isNotEmpty ? label : '위치',
            style: AppTextStyles.sectionHead),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: NaverMap(
        options: NaverMapViewOptions(
          initialCameraPosition:
              NCameraPosition(target: NLatLng(lat, lng), zoom: 16),
        ),
        onMapReady: (controller) {
          controller.addOverlay(
            NMarker(id: 'fs', position: NLatLng(lat, lng)),
          );
        },
      ),
    );
  }
}

/// 시스템 메시지 — 배경 없이 캡션 한 줄 가운데.
class _SystemMessage extends StatelessWidget {
  final ChatMessage message;
  const _SystemMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Text(
        message.content,
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      ),
    );
  }
}
