import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

const int kMorningNotifId = 1001;
const int kEveningNotifId = 1002;
const int kIstighfarNotifId = 1003;

const List<String> kStandardDhikrs = [
  'سُبْحَانَ الله',
  'لَا إِلَهَ إِلَّا الله',
  'أَسْتَغْفِرُ اللهَ العَظِيمَ وَأَتُوبُ إِلَيْه',
];

// ==================== Time Helper ====================

String formatTime12(TimeOfDay t) {
  final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final period = t.hour < 12 ? 'ص' : 'م';
  return '${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
}

String formatDateTime12(DateTime t) {
  final hour = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
  final period = t.hour < 12 ? 'ص' : 'م';
  return '${t.day}/${t.month}  •  ${hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $period';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  // ✅ إصلاح المنطقة الزمنية لمصر
  tz.setLocalLocation(tz.getLocation('Africa/Cairo'));

  const androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await notificationsPlugin.initialize(initSettings);

  runApp(const IstaghfirApp());
}

class IstaghfirApp extends StatelessWidget {
  const IstaghfirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Istaghfar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E63)),
      ),
      home: const SplashPage(),
    );
  }
}

// ==================== Notification Service ====================

class NotificationService {
  static const AndroidNotificationDetails _androidDetails =
      AndroidNotificationDetails(
    'istaghfar_channel',
    'تذكيرات إستغفر',
    channelDescription: 'تذكيرات الأذكار والمهام اليومية',
    importance: Importance.high,
    priority: Priority.high,
    playSound: true,
  );

  static Future<void> requestPermissions() async {
    final android = notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  static Future<void> scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await notificationsPlugin.cancel(id);
    await notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      const NotificationDetails(android: _androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancel(int id) async {
    await notificationsPlugin.cancel(id);
  }

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

// ==================== Splash Page ====================

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();

    Timer(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const MainScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFAF6EF), Color(0xFFFFF3D4)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SizedBox(
              width: 340,
              height: 340,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _rotateController,
                    child: SizedBox(
                      width: 320,
                      height: 320,
                      child: Stack(
                        children: List.generate(33, (i) {
                          final angle = (i / 33) * 2 * pi - pi / 2;
                          const radius = 145.0;
                          final x = radius * cos(angle);
                          final y = radius * sin(angle);
                          return Positioned(
                            left: 160 + x - 6,
                            top: 160 + y - 6,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD4AF37),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  Text(
                    'إستَغفِر',
                    style: GoogleFonts.amiri(
                      fontSize: 58,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFD4AF37),
                      shadows: [
                        Shadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.3),
                          blurRadius: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Storage ====================

class Storage {
  static const String _dailyKey = 'daily_items_v1';
  static const String _religiousKey = 'religious_items_v2';
  static const String _dhikrKey = 'dhikr_entries_v1';
  static const String _customDhikrKey = 'custom_dhikrs_v1';
  static const String _hapticKey = 'haptic_enabled_v1';
  static const String _inboxKey = 'inbox_items_v1';

  static const String _morningEnabledKey = 'notif_morning_enabled';
  static const String _morningHourKey = 'notif_morning_hour';
  static const String _morningMinKey = 'notif_morning_min';
  static const String _eveningEnabledKey = 'notif_evening_enabled';
  static const String _eveningHourKey = 'notif_evening_hour';
  static const String _eveningMinKey = 'notif_evening_min';
  static const String _istighfarEnabledKey = 'notif_istighfar_enabled';
  static const String _istighfarHourKey = 'notif_istighfar_hour';
  static const String _istighfarMinKey = 'notif_istighfar_min';

  static Future<void> saveDailyItems(List<dynamic> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyKey, jsonEncode(_serializeItems(items)));
  }

  static Future<List<dynamic>> loadDailyItems() async {
    final prefs = await SharedPreferences.getInstance();
    return _deserializeItems(prefs.getString(_dailyKey));
  }

  static Future<void> saveReligiousItems(List<dynamic> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_religiousKey, jsonEncode(_serializeItems(items)));
  }

  static Future<List<dynamic>> loadReligiousItems() async {
    final prefs = await SharedPreferences.getInstance();
    return _deserializeItems(prefs.getString(_religiousKey));
  }

  static List<Map<String, dynamic>> _serializeItems(List<dynamic> items) {
    return items.map((item) {
      if (item is TaskFolder) {
        return {
          'type': 'folder',
          'id': item.id,
          'name': item.name,
          'scheduledTime': item.scheduledTime?.toIso8601String(),
          'tasks': item.tasks
              .map((t) => {
                    'id': t.id,
                    'title': t.title,
                    'isDone': t.isDone,
                    'isCancelled': t.isCancelled,
                    'scheduledTime': t.scheduledTime?.toIso8601String(),
                  })
              .toList(),
        };
      } else if (item is TaskItem) {
        return {
          'type': 'task',
          'id': item.id,
          'title': item.title,
          'isDone': item.isDone,
          'isCancelled': item.isCancelled,
          'scheduledTime': item.scheduledTime?.toIso8601String(),
        };
      }
      return <String, dynamic>{};
    }).toList();
  }

  static List<dynamic> _deserializeItems(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((item) {
        if (item['type'] == 'folder') {
          final tasks = (item['tasks'] as List)
              .map((t) => TaskItem(
                    id: t['id'],
                    title: t['title'],
                    isDone: t['isDone'] ?? false,
                    isCancelled: t['isCancelled'] ?? false,
                    scheduledTime: t['scheduledTime'] != null
                        ? DateTime.tryParse(t['scheduledTime'])
                        : null,
                  ))
              .toList();
          return TaskFolder(
            id: item['id'],
            name: item['name'],
            tasks: tasks,
            scheduledTime: item['scheduledTime'] != null
                ? DateTime.tryParse(item['scheduledTime'])
                : null,
          );
        } else {
          return TaskItem(
              id: item['id'],
              title: item['title'],
              isDone: item['isDone'] ?? false,
              isCancelled: item['isCancelled'] ?? false,
              scheduledTime: item['scheduledTime'] != null
                  ? DateTime.tryParse(item['scheduledTime'])
                  : null);
        }
      }).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveDhikrEntry(DhikrEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadDhikrEntries();
    existing.add(entry);
    final data = existing.map((e) => e.toJson()).toList();
    await prefs.setString(_dhikrKey, jsonEncode(data));
  }

  static Future<List<DhikrEntry>> loadDhikrEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dhikrKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((e) => DhikrEntry.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveCustomDhikr(String dhikr) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCustomDhikrs();
    if (!existing.contains(dhikr)) {
      existing.add(dhikr);
      await prefs.setStringList(_customDhikrKey, existing);
    }
  }

  static Future<void> updateCustomDhikr(String oldDhikr, String newDhikr) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await loadCustomDhikrs();
    final idx = existing.indexOf(oldDhikr);
    if (idx != -1) {
      existing[idx] = newDhikr;
      await prefs.setStringList(_customDhikrKey, existing);
    } else {
      existing.add(newDhikr);
      await prefs.setStringList(_customDhikrKey, existing);
    }
  }

  static Future<List<String>> loadCustomDhikrs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_customDhikrKey) ?? [];
  }

  static Future<bool> loadHapticEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticKey) ?? true;
  }

  static Future<void> saveHapticEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, value);
  }

  static Future<bool> getMorningEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_morningEnabledKey) ?? false;
  }

  static Future<void> setMorningEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_morningEnabledKey, v);
  }

  static Future<TimeOfDay> getMorningTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
        hour: p.getInt(_morningHourKey) ?? 6,
        minute: p.getInt(_morningMinKey) ?? 0);
  }

  static Future<void> setMorningTime(TimeOfDay t) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_morningHourKey, t.hour);
    await p.setInt(_morningMinKey, t.minute);
  }

  static Future<bool> getEveningEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_eveningEnabledKey) ?? false;
  }

  static Future<void> setEveningEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_eveningEnabledKey, v);
  }

  static Future<TimeOfDay> getEveningTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
        hour: p.getInt(_eveningHourKey) ?? 17,
        minute: p.getInt(_eveningMinKey) ?? 0);
  }

  static Future<void> setEveningTime(TimeOfDay t) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_eveningHourKey, t.hour);
    await p.setInt(_eveningMinKey, t.minute);
  }

  static Future<bool> getIstighfarEnabled() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_istighfarEnabledKey) ?? false;
  }

  static Future<void> setIstighfarEnabled(bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_istighfarEnabledKey, v);
  }

  static Future<TimeOfDay> getIstighfarTime() async {
    final p = await SharedPreferences.getInstance();
    return TimeOfDay(
        hour: p.getInt(_istighfarHourKey) ?? 12,
        minute: p.getInt(_istighfarMinKey) ?? 0);
  }

  static Future<void> setIstighfarTime(TimeOfDay t) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_istighfarHourKey, t.hour);
    await p.setInt(_istighfarMinKey, t.minute);
  }

  // ===== Inbox =====
  static Future<List<InboxItem>> loadInbox() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_inboxKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data.map((e) => InboxItem.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveInbox(List<InboxItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        _inboxKey, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> addInboxItem(InboxItem item) async {
    final items = await loadInbox();
    if (items.any((x) => x.id == item.id)) return;
    items.add(item);
    await saveInbox(items);
  }

  static Future<int> unreadCount() async {
    final items = await loadInbox();
    return items.where((e) => !e.isRead).length;
  }

  static Future<void> markAllRead() async {
    final items = await loadInbox();
    for (final i in items) {
      i.isRead = true;
    }
    await saveInbox(items);
  }
}

// ==================== Models ====================

class TaskItem {
  String id;
  String title;
  bool isDone;
  bool isCancelled;
  DateTime? scheduledTime;

  TaskItem({
    String? id,
    required this.title,
    this.isDone = false,
    this.isCancelled = false,
    this.scheduledTime,
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();
}

class TaskFolder {
  String id;
  String name;
  List<TaskItem> tasks;
  DateTime? scheduledTime;

  TaskFolder({
    String? id,
    required this.name,
    List<TaskItem>? tasks,
    this.scheduledTime,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        tasks = tasks ?? [];
}

class DhikrEntry {
  String dhikr;
  int count;
  String date;
  DhikrEntry({required this.dhikr, required this.count, required this.date});

  Map<String, dynamic> toJson() =>
      {'dhikr': dhikr, 'count': count, 'date': date};
  factory DhikrEntry.fromJson(Map<String, dynamic> json) => DhikrEntry(
      dhikr: json['dhikr'], count: json['count'], date: json['date']);
}

class InboxItem {
  String id;
  String title;
  String body;
  DateTime timestamp;
  bool isRead;

  InboxItem({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        timestamp: DateTime.parse(j['timestamp']),
        isRead: j['isRead'] ?? false,
      );
}

class AddResult {
  final String title;
  final DateTime? scheduledTime;
  final bool isFolder;
  AddResult(
      {required this.title, this.scheduledTime, required this.isFolder});
}

// ==================== MainScreen ====================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  final GlobalKey<ProfilePageState> _profileKey =
      GlobalKey<ProfilePageState>();
  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await NotificationService.requestPermissions();
      await _checkFiredNotifications();
    });
  }

  Future<void> _checkFiredNotifications() async {
    final now = DateTime.now();
    final today = '${now.year}${now.month}${now.day}';

    if (await Storage.getMorningEnabled()) {
      final t = await Storage.getMorningTime();
      final fireTime =
          DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (now.isAfter(fireTime)) {
        final items = await Storage.loadInbox();
        if (!items.any((x) => x.id == 'morning_$today')) {
          await Storage.addInboxItem(InboxItem(
            id: 'morning_$today',
            title: '🌅 أذكار الصباح',
            body: 'صباح الخير! ابدأ يومك بأذكار الصباح',
            timestamp: fireTime,
          ));
        }
      }
    }

    if (await Storage.getEveningEnabled()) {
      final t = await Storage.getEveningTime();
      final fireTime =
          DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (now.isAfter(fireTime)) {
        final items = await Storage.loadInbox();
        if (!items.any((x) => x.id == 'evening_$today')) {
          await Storage.addInboxItem(InboxItem(
            id: 'evening_$today',
            title: '🌙 أذكار المساء',
            body: 'متنساش أذكار المساء قبل ما تنام',
            timestamp: fireTime,
          ));
        }
      }
    }

    if (await Storage.getIstighfarEnabled()) {
      final t = await Storage.getIstighfarTime();
      final fireTime =
          DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (now.isAfter(fireTime)) {
        final items = await Storage.loadInbox();
        if (!items.any((x) => x.id == 'istighfar_$today')) {
          await Storage.addInboxItem(InboxItem(
            id: 'istighfar_$today',
            title: '📿 وقت الاستغفار',
            body: 'خد دقيقة استغفر فيها ربنا',
            timestamp: fireTime,
          ));
        }
      }
    }

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(index,
        duration: _animDuration, curve: Curves.easeInOutCubic);
  }

  void _openReligiousTasks() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ReligiousTasksPage()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        onReligiousTasksTap: _openReligiousTasks,
        onDailyTasksTap: () => _goToPage(1),
      ),
      const TasksPage(),
      ProfilePage(key: _profileKey),
      const SettingsPage(),
    ];

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        reverse: true,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            _profileKey.currentState?.refreshStats();
          }
        },
        children: pages,
      ),
      bottomNavigationBar:
          GlassBottomNavBar(currentIndex: _currentIndex, onTap: _goToPage),
    );
  }
}

// ==================== Glass Bottom Nav ====================

class GlassBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const GlassBottomNavBar(
      {super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      Icons.home_rounded,
      Icons.task_alt_rounded,
      Icons.person_rounded,
      Icons.settings_rounded
    ];
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: EdgeInsets.only(left: 20, right: 20, bottom: bottomPadding + 10),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              final indicatorLeft =
                  (items.length - 1 - currentIndex) * itemWidth +
                      (itemWidth - 60) / 2;
              return Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOutCubic,
                    left: indicatorLeft,
                    top: 5,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4))
                        ],
                      ),
                    ),
                  ),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: List.generate(items.length, (index) {
                      final isSelected = currentIndex == index;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTap(index),
                          behavior: HitTestBehavior.opaque,
                          child: SizedBox(
                            height: 70,
                            child: Center(
                              child: AnimatedScale(
                                scale: isSelected ? 1.2 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOutCubic,
                                child: Icon(items[index],
                                    color: isSelected
                                        ? const Color(0xFFD4AF37)
                                        : Colors.grey.shade600,
                                    size: 28),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ==================== Helper: تدفق اختيار الذكر ====================

Future<void> startDhikrFlow(BuildContext context) async {
  final result = await DhikrSelectionDialog.show(context);
  await processDhikrResult(context, result);
}

Future<void> processDhikrResult(BuildContext context, String? result) async {
  if (result == null) return;
  if (!context.mounted) return;

  if (result == DhikrSelectionDialog.kCustomAction) {
    final choice = await DhikrSelectionDialog.showCustomOptions(context);
    if (!context.mounted) return;

    if (choice == 'write') {
      final text = await DhikrSelectionDialog.showWriteDialog(context);
      if (!context.mounted) return;
      if (text != null && text.isNotEmpty) {
        await Storage.saveCustomDhikr(text);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم حفظ الدعاء ✓',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => TasbeehPage(dhikr: text)));
      }
    } else if (choice == 'skip') {
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const TasbeehPage(dhikr: '')));
    }
  } else {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => TasbeehPage(dhikr: result)));
  }
}

// ==================== HomePage ====================

class HomePage extends StatefulWidget {
  final VoidCallback onReligiousTasksTap;
  final VoidCallback onDailyTasksTap;
  const HomePage(
      {super.key,
      required this.onReligiousTasksTap,
      required this.onDailyTasksTap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _loadUnread();
  }

  Future<void> _loadUnread() async {
    final c = await Storage.unreadCount();
    if (mounted) setState(() => _unread = c);
  }

  Future<void> _openInbox() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const InboxPage()));
    await _loadUnread();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('إستَغفِر',
            style: GoogleFonts.reemKufi(
                fontWeight: FontWeight.bold,
                fontSize: 32,
                color: Colors.black)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.black, size: 28),
                onPressed: _openInbox,
              ),
              if (_unread > 0)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.red.withOpacity(0.5),
                            blurRadius: 6),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => startDhikrFlow(context),
              child: _buildCard('إستغفر', 'سبحة إلكترونية'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
                onTap: widget.onReligiousTasksTap,
                child: _buildCard(
                    'مهام دينية', 'تستطيع أن تكتب أي مهمة دينية لإنجازها')),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerRight,
              child: Text('مميزات إضافية >',
                  style: GoogleFonts.reemKufi(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: widget.onDailyTasksTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8)
                  ],
                ),
                child: Center(
                    child: Text('مهمات يومية',
                        style: GoogleFonts.cairo(
                            fontSize: 20, fontWeight: FontWeight.bold))),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.cairo(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: GoogleFonts.cairo(
                  fontSize: 14, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ==================== Inbox Page ====================

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});
  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<InboxItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await Storage.loadInbox();
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  void dispose() {
    Storage.markAllRead();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newItems = _items.where((i) => !i.isRead).toList();
    final readItems = _items.where((i) => i.isRead).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text('الإشعارات',
              style: GoogleFonts.reemKufi(
                  fontWeight: FontWeight.bold, fontSize: 24)),
          bottom: TabBar(
            indicatorColor: const Color(0xFFD4AF37),
            indicatorWeight: 3,
            labelColor: Colors.black,
            unselectedLabelColor: Colors.grey.shade600,
            labelStyle:
                GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: [
              Tab(text: 'جديد (${newItems.length})'),
              Tab(text: 'مقروء (${readItems.length})'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(newItems, isNew: true),
                  _buildList(readItems, isNew: false),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<InboxItem> items, {required bool isNew}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(isNew ? 'مفيش إشعارات جديدة' : 'مفيش إشعارات مقروءة',
                style: GoogleFonts.cairo(
                    fontSize: 18, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: isNew ? 3 : 1,
          color: isNew ? Colors.white : const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isNew
                ? const BorderSide(color: Color(0xFFD4AF37), width: 1.5)
                : BorderSide.none,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isNew
                        ? const Color(0xFFD4AF37).withOpacity(0.15)
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.notifications_active,
                      color:
                          isNew ? const Color(0xFFD4AF37) : Colors.grey,
                      size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(item.title,
                                style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                          ),
                          if (isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: Colors.red.shade200),
                              ),
                              child: Text('جديد',
                                  style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(item.body,
                          style: GoogleFonts.cairo(
                              fontSize: 13, color: Colors.grey.shade700)),
                      const SizedBox(height: 6),
                      Text(formatDateTime12(item.timestamp),
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== Dhikr Selection Dialog ====================

class DhikrSelectionDialog {
  static const String kCustomAction = '__CUSTOM_ACTION__';

  static Future<String?> show(BuildContext context) async {
    final customs = await Storage.loadCustomDhikrs();
    if (!context.mounted) return null;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('هَتَقُول إيه؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
                fontSize: 26, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final d in kStandardDhikrs) _option(dialogContext, d),
              if (customs.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('أذكارك الخاصة:',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: Colors.grey.shade600)),
                ),
                for (final c in customs) _option(dialogContext, c),
              ],
              _option(dialogContext, 'دُعَاء تَانِي',
                  value: kCustomAction, isSpecial: true),
            ],
          ),
        ),
      ),
    );
  }

  static Future<String?> showContinuation(BuildContext context,
      {required String currentDhikr}) async {
    final customs = await Storage.loadCustomDhikrs();
    if (!context.mounted) return null;

    final options = <String>[];
    for (final d in kStandardDhikrs) {
      if (d != currentDhikr) options.add(d);
    }
    for (final c in customs) {
      if (c != currentDhikr) options.add(c);
    }

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('تَحِبّ تِكَمِّل بِإيه؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
                fontSize: 24, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in options) _option(dialogContext, o),
              _option(dialogContext, 'دُعَاء تَانِي',
                  value: kCustomAction, isSpecial: true),
            ],
          ),
        ),
      ),
    );
  }

  static Future<String?> showCustomOptions(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('حابب تعمل إيه؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontSize: 20, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
              title: Text('حابب تكتب الدعاء',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(dialogContext, 'write'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward, color: Colors.grey),
              title: Text('كمل من غير حاجة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(dialogContext, 'skip'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> showWriteDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('اكتب الدعاء',
            style: GoogleFonts.amiri(
                fontWeight: FontWeight.bold, fontSize: 22)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.amiri(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'مثلاً: اللهم صل على محمد',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(15))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton.icon(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              icon: const Icon(Icons.save_alt, color: Colors.green, size: 20),
              label: Text('حفظ',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, color: Colors.green))),
        ],
      ),
    );
  }

  static Widget _option(BuildContext context, String text,
      {String? value, bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context, value ?? text),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isSpecial ? const Color(0xFFD4AF37) : Colors.white,
            foregroundColor: isSpecial ? Colors.white : Colors.black87,
            elevation: 2,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          child: Text(text,
              style: GoogleFonts.amiri(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSpecial ? Colors.white : Colors.black87)),
        ),
      ),
    );
  }
}

// ==================== Add Options Dialog ====================

class AddOptionsDialog {
  static Future<String?> show(BuildContext context) async {
    return showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Add Options',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) =>
          const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
              opacity: animation, child: _buildDialog(context)),
        );
      },
    );
  }

  static Widget _buildDialog(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF6EF),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
                color: const Color(0xFFD4AF37).withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [Color(0xFFD4AF37), Color(0xFFB8941F)],
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFFD4AF37).withOpacity(0.4),
                        blurRadius: 20),
                  ],
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text('إضافة جديدة',
                  style: GoogleFonts.reemKufi(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(height: 6),
              Text('اختار النوع اللي عايز تضيفه',
                  style: GoogleFonts.cairo(
                      fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              _buildOptionCard(
                context,
                icon: Icons.folder_rounded,
                iconColor: const Color(0xFF5C9CE6),
                iconBg: const Color(0xFFE8F2FD),
                title: 'مجلد جديد',
                subtitle: 'لتجميع المهام في مكان واحد',
                onTap: () => Navigator.pop(context, 'folder'),
              ),
              const SizedBox(height: 12),
              _buildOptionCard(
                context,
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF4CAF50),
                iconBg: const Color(0xFFE8F5E9),
                title: 'مهمة سريعة',
                subtitle: 'مهمة مباشرة من غير مجلد',
                onTap: () => Navigator.pop(context, 'task'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: GoogleFonts.cairo(
                        fontSize: 15,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildOptionCard(BuildContext context,
      {required IconData icon,
      required Color iconColor,
      required Color iconBg,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: iconColor.withOpacity(0.2), width: 1),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(15)),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios_new_rounded,
                  size: 14, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TasbeehPage ====================

class TasbeehPage extends StatefulWidget {
  final String dhikr;
  const TasbeehPage({super.key, required this.dhikr});
  @override
  State<TasbeehPage> createState() => _TasbeehPageState();
}

class _TasbeehPageState extends State<TasbeehPage> {
  int count = 0;
  static const int totalCircles = 33;
  double _scale = 1.0;
  late String _currentDhikr;

  @override
  void initState() {
    super.initState();
    _currentDhikr = widget.dhikr;
  }

  int get litCount {
    if (count == 0) return 0;
    return ((count - 1) % totalCircles) + 1;
  }

  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }

  bool get _isCustomDhikr =>
      _currentDhikr.isNotEmpty && !kStandardDhikrs.contains(_currentDhikr);

  Future<void> _increment() async {
    final hapticEnabled = await Storage.loadHapticEnabled();
    if (hapticEnabled) HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      count++;
      _scale = 1.08;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  Future<void> _editCustomDhikr() async {
    final controller = TextEditingController(text: _currentDhikr);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('تعديل الدعاء',
            style: GoogleFonts.amiri(
                fontWeight: FontWeight.bold, fontSize: 22)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.amiri(fontSize: 18),
          decoration: const InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(15))),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton.icon(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(dialogContext, controller.text.trim());
                }
              },
              icon: const Icon(Icons.save_alt, color: Colors.green, size: 20),
              label: Text('حفظ',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, color: Colors.green))),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await Storage.updateCustomDhikr(_currentDhikr, result);
      setState(() => _currentDhikr = result);
    }
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('حابب تعمل إيه؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold, fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.save_alt, color: Colors.green),
              title: Text('حابب تحفظ العدد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(dialogContext);
                _saveCount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: Text('تبدأ من جديد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(dialogContext);
                setState(() => count = 0);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCount() async {
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('مفيش عدد تحفظه', style: GoogleFonts.cairo()),
            backgroundColor: Colors.orange),
      );
      return;
    }
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month}-${now.day}';
    final dhikrName = _currentDhikr.isEmpty ? 'ذكر حر' : _currentDhikr;
    await Storage.saveDhikrEntry(
        DhikrEntry(dhikr: dhikrName, count: count, date: dateStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ العدد في ملف في المهام الدينية ✓',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    final nextResult = await DhikrSelectionDialog.showContinuation(context,
        currentDhikr: _currentDhikr);
    if (!mounted) return;
    if (nextResult == null) return;

    if (nextResult == DhikrSelectionDialog.kCustomAction) {
      final choice = await DhikrSelectionDialog.showCustomOptions(context);
      if (!mounted) return;
      if (choice == 'write') {
        final text = await DhikrSelectionDialog.showWriteDialog(context);
        if (!mounted) return;
        if (text != null && text.isNotEmpty) {
          await Storage.saveCustomDhikr(text);
          if (!mounted) return;
          Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => TasbeehPage(dhikr: text)));
        }
      } else if (choice == 'skip') {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const TasbeehPage(dhikr: '')));
      }
    } else {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) => TasbeehPage(dhikr: nextResult)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6EF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_currentDhikr.isEmpty ? 'سُبْحَة' : _currentDhikr,
            style: GoogleFonts.amiri(
                fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          if (_isCustomDhikr)
            IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: _editCustomDhikr),
          IconButton(
              icon: const Icon(Icons.save_alt, color: Colors.black),
              onPressed: _showSaveOptions),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight * 0.75);
          final outerRadius = size / 2 - 20;
          const smallSize = 22.0;
          final smallRadius = outerRadius - smallSize / 2 - 5;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(totalCircles, (i) {
                        final angle = (i / totalCircles) * 2 * pi - pi / 2;
                        final x = smallRadius * cos(angle);
                        final y = smallRadius * sin(angle);
                        final isLit = i < litCount;
                        return Positioned(
                          left: size / 2 + x - smallSize / 2,
                          top: size / 2 + y - smallSize / 2,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: smallSize,
                            height: smallSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLit
                                  ? const Color(0xFFD4AF37)
                                  : Colors.grey.shade300,
                              boxShadow: isLit
                                  ? [
                                      BoxShadow(
                                          color: const Color(0xFFD4AF37)
                                              .withOpacity(0.6),
                                          blurRadius: 10)
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                      GestureDetector(
                        onTap: _increment,
                        child: AnimatedScale(
                          scale: _scale,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            width: size * 0.55,
                            height: size * 0.55,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    spreadRadius: 2)
                              ],
                              border: Border.all(
                                  color: const Color(0xFFD4AF37), width: 3),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_toArabicNumber(count),
                                    style: GoogleFonts.amiri(
                                        fontSize: 72,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        height: 1)),
                                if (_currentDhikr.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(_currentDhikr,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.amiri(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey.shade700)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                TextButton.icon(
                  onPressed: _showSaveOptions,
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.black),
                  label: Text('حفظ / بدء جديد',
                      style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==================== Religious Tasks ====================

class ReligiousTasksPage extends StatefulWidget {
  const ReligiousTasksPage({super.key});
  @override
  State<ReligiousTasksPage> createState() => _ReligiousTasksPageState();
}

class _ReligiousTasksPageState extends State<ReligiousTasksPage> {
  List<dynamic> items = [];
  List<DhikrEntry> dhikrEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var loaded = await Storage.loadReligiousItems();
    loaded = _removeExpiredItems(loaded);
    final dhikrs = await Storage.loadDhikrEntries();
    if (!mounted) return;
    setState(() {
      items = loaded;
      dhikrEntries = dhikrs;
      _isLoading = false;
    });
    await Storage.saveReligiousItems(items);
  }

  List<dynamic> _removeExpiredItems(List<dynamic> list) {
    final now = DateTime.now();
    return list.map((item) {
      if (item is TaskItem) {
        if (item.scheduledTime != null && item.scheduledTime!.isBefore(now)) {
          return null;
        }
        return item;
      } else if (item is TaskFolder) {
        if (item.scheduledTime != null && item.scheduledTime!.isBefore(now)) {
          return null;
        }
        item.tasks.removeWhere((t) =>
            t.scheduledTime != null && t.scheduledTime!.isBefore(now));
        return item;
      }
      return null;
    }).whereType<dynamic>().toList();
  }

  Future<void> _save() async => await Storage.saveReligiousItems(items);

  void _openAddTaskPage() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result is AddResult && !result.isFolder) {
      setState(() => items.add(TaskItem(
            title: result.title,
            scheduledTime: result.scheduledTime,
          )));
      _save();
    }
  }

  void _openAddFolderPage() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const AddTaskPage(isFolder: true)));
    if (result != null && result is AddResult && result.isFolder) {
      setState(() => items.add(TaskFolder(
            name: result.title,
            scheduledTime: result.scheduledTime,
          )));
      _save();
    }
  }

  Future<void> _showAddOptions() async {
    final choice = await AddOptionsDialog.show(context);
    if (!mounted) return;
    if (choice == 'folder') {
      _openAddFolderPage();
    } else if (choice == 'task') {
      _openAddTaskPage();
    }
  }

  Future<void> _deleteFolder(TaskFolder folder) async {
    final ok = await _confirmDelete(
        'حذف المجلد؟', 'هيتم حذف المجلد وكل المهام اللي جواه');
    if (ok) {
      setState(() => items.remove(folder));
      await _save();
    }
  }

  Future<bool> _confirmDelete(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.reemKufi(fontWeight: FontWeight.bold)),
            content: Text(body, style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo())),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('حذف',
                      style: GoogleFonts.cairo(
                          color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.black, size: 28),
            onPressed: () => Navigator.pop(context)),
        title: Text('مهامك الدينية',
            style: GoogleFonts.reemKufi(
                fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : (items.isEmpty && dhikrEntries.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text('لسه مفيش حاجة هنا',
                          style: GoogleFonts.cairo(
                              fontSize: 20, color: Colors.grey.shade500)),
                      const SizedBox(height: 10),
                      Text('اضغط على + عشان تضيف مهمة أو مجلد',
                          style: GoogleFonts.cairo(
                              fontSize: 14, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (dhikrEntries.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('📿 العدادات المحفوظة',
                            style: GoogleFonts.reemKufi(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ...dhikrEntries.reversed.map((e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15)),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3D4),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.format_quote,
                                    color: Color(0xFFD4AF37)),
                              ),
                              title: Text(e.dhikr,
                                  style: GoogleFonts.amiri(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                              subtitle: Text(
                                  'العدد: ${e.count}',
                                  style: GoogleFonts.cairo(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ),
                          )),
                      const SizedBox(height: 20),
                    ],
                    if (items.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('✓ المهام والمجلدات',
                            style: GoogleFonts.reemKufi(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ...items.map((item) => _buildItemCard(item)),
                    ],
                  ],
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130),
        child: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: Colors.black,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildItemCard(dynamic item) {
    if (item is TaskFolder) {
      return FolderCard(
        folder: item,
        onChanged: () {
          setState(() {});
          _save();
        },
        onDelete: () => _deleteFolder(item),
      );
    } else if (item is TaskItem) {
      return TaskCard(
        task: item,
        onChanged: () {
          setState(() {});
          _save();
        },
        onDelete: () async {
          final ok = await _confirmDelete(
              'حذف المهمة؟', 'هيتم حذف المهمة نهائياً');
          if (ok) {
            setState(() => items.remove(item));
            await _save();
          }
        },
      );
    }
    return const SizedBox.shrink();
  }
}

// ==================== Folder Card ====================

class FolderCard extends StatelessWidget {
  final TaskFolder folder;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const FolderCard(
      {super.key,
      required this.folder,
      required this.onChanged,
      required this.onDelete});

  String? _formatSchedule() {
    if (folder.scheduledTime == null) return null;
    return formatDateTime12(folder.scheduledTime!);
  }

  @override
  Widget build(BuildContext context) {
    final scheduleText = _formatSchedule();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.folder_rounded, color: Colors.blue),
            ),
            title: Text(folder.name,
                style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Text('${folder.tasks.length} مهمة',
                style: GoogleFonts.cairo()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.delete_outline,
                        color: Colors.red, size: 22),
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 14),
              ],
            ),
            onTap: () {
              Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              FolderDetailPage(folder: folder)))
                  .then((_) => onChanged());
            },
          ),
          if (scheduleText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: Colors.blue.shade400),
                  const SizedBox(width: 4),
                  Text(scheduleText,
                      style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== Task Card ====================

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onChanged;
  final VoidCallback? onDelete;

  const TaskCard(
      {super.key,
      required this.task,
      required this.onChanged,
      this.onDelete});

  void _toggleDone() {
    task.isDone = !task.isDone;
    if (task.isDone) task.isCancelled = false;
    onChanged();
  }

  void _toggleCancelled() {
    task.isCancelled = !task.isCancelled;
    if (task.isCancelled) task.isDone = false;
    onChanged();
  }

  String? _formatSchedule() {
    if (task.scheduledTime == null) return null;
    return formatDateTime12(task.scheduledTime!);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDone = task.isDone;
    final bool isCancelled = task.isCancelled;
    final bool isGreyed = isDone || isCancelled;
    final String? scheduleText = _formatSchedule();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: _toggleDone,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  GestureDetector(
                    onTap: _toggleDone,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone
                            ? const Color(0xFFD4AF37)
                            : Colors.transparent,
                        border: Border.all(
                            color: isDone
                                ? const Color(0xFFD4AF37)
                                : Colors.grey.shade400,
                            width: 2),
                      ),
                      child: isDone
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 16)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(task.title,
                        style: GoogleFonts.cairo(
                          decoration:
                              isGreyed ? TextDecoration.lineThrough : null,
                          color: isGreyed ? Colors.grey : Colors.black,
                        )),
                  ),
                  if (onDelete != null)
                    GestureDetector(
                      onTap: onDelete,
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.delete_outline,
                            color: Colors.red, size: 22),
                      ),
                    ),
                  GestureDetector(
                    onTap: _toggleCancelled,
                    behavior: HitTestBehavior.opaque,
                    child: isDone
                        ? const Icon(Icons.check_circle,
                            color: Colors.green, size: 22)
                        : isCancelled
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.red.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.close,
                                        size: 14,
                                        color: Colors.red.shade700),
                                    const SizedBox(width: 4),
                                    Text('متخطّية',
                                        style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade700)),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.orange.shade200),
                                ),
                                child: Text('لم تُنجز بعد',
                                    style: GoogleFonts.cairo(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade800)),
                              ),
                  ),
                ],
              ),
              if (scheduleText != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Row(
                    children: [
                      Icon(Icons.schedule,
                          size: 14, color: Colors.blue.shade400),
                      const SizedBox(width: 4),
                      Text(scheduleText,
                          style: GoogleFonts.cairo(
                              fontSize: 11,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Daily Tasks ====================

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});
  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  List<dynamic> items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var loaded = await Storage.loadDailyItems();
    loaded = _removeExpiredItems(loaded);
    if (!mounted) return;
    setState(() {
      items = loaded;
      _isLoading = false;
    });
    await Storage.saveDailyItems(items);
  }

  List<dynamic> _removeExpiredItems(List<dynamic> list) {
    final now = DateTime.now();
    return list.map((item) {
      if (item is TaskItem) {
        if (item.scheduledTime != null && item.scheduledTime!.isBefore(now)) {
          return null;
        }
        return item;
      } else if (item is TaskFolder) {
        if (item.scheduledTime != null && item.scheduledTime!.isBefore(now)) {
          return null;
        }
        item.tasks.removeWhere((t) =>
            t.scheduledTime != null && t.scheduledTime!.isBefore(now));
        return item;
      }
      return null;
    }).whereType<dynamic>().toList();
  }

  Future<void> _save() async => await Storage.saveDailyItems(items);

  void _openAddTaskPage() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result is AddResult && !result.isFolder) {
      setState(() => items.add(TaskItem(
            title: result.title,
            scheduledTime: result.scheduledTime,
          )));
      _save();
    }
  }

  void _openAddFolderPage() async {
    final result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => const AddTaskPage(isFolder: true)));
    if (result != null && result is AddResult && result.isFolder) {
      setState(() => items.add(TaskFolder(
            name: result.title,
            scheduledTime: result.scheduledTime,
          )));
      _save();
    }
  }

  Future<void> _showAddOptions() async {
    final choice = await AddOptionsDialog.show(context);
    if (!mounted) return;
    if (choice == 'folder') {
      _openAddFolderPage();
    } else if (choice == 'task') {
      _openAddTaskPage();
    }
  }

  Future<bool> _confirmDelete(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title,
                style: GoogleFonts.reemKufi(fontWeight: FontWeight.bold)),
            content: Text(body, style: GoogleFonts.cairo()),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('إلغاء', style: GoogleFonts.cairo())),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('حذف',
                      style: GoogleFonts.cairo(
                          color: Colors.red, fontWeight: FontWeight.bold))),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text('مهمات يومية',
            style: GoogleFonts.reemKufi(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 20),
                      Text('لسه مفيش حاجة هنا',
                          style: GoogleFonts.cairo(
                              fontSize: 20, color: Colors.grey.shade500)),
                      const SizedBox(height: 10),
                      Text('اضغط على + عشان تضيف مهمة أو مجلد',
                          style: GoogleFonts.cairo(
                              fontSize: 14, color: Colors.grey.shade400)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is TaskFolder) {
                      return FolderCard(
                        folder: item,
                        onChanged: () {
                          setState(() {});
                          _save();
                        },
                        onDelete: () async {
                          final ok = await _confirmDelete('حذف المجلد؟',
                              'هيتم حذف المجلد وكل المهام اللي جواه');
                          if (ok) {
                            setState(() => items.remove(item));
                            await _save();
                          }
                        },
                      );
                    } else if (item is TaskItem) {
                      return TaskCard(
                        task: item,
                        onChanged: () {
                          setState(() {});
                          _save();
                        },
                        onDelete: () async {
                          final ok = await _confirmDelete(
                              'حذف المهمة؟', 'هيتم حذف المهمة نهائياً');
                          if (ok) {
                            setState(() => items.remove(item));
                            await _save();
                          }
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130),
        child: FloatingActionButton(
          onPressed: _showAddOptions,
          backgroundColor: Colors.black,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ==================== Add Task Page ====================

class AddTaskPage extends StatefulWidget {
  final bool isFolder;
  const AddTaskPage({super.key, this.isFolder = false});
  @override
  State<AddTaskPage> createState() => _AddTaskPageState();
}

class _AddTaskPageState extends State<AddTaskPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  DateTime? _scheduledTime;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    String finalTitle = '';
    if (title.isNotEmpty && content.isNotEmpty) {
      finalTitle = '$title\n$content';
    } else if (title.isNotEmpty) {
      finalTitle = title;
    } else if (content.isNotEmpty) {
      finalTitle = content;
    }

    if (finalTitle.isEmpty) return;

    Navigator.pop(
        context,
        AddResult(
          title: finalTitle,
          scheduledTime: _scheduledTime,
          isFolder: widget.isFolder,
        ));
  }

  void _shareNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    String text = title.isNotEmpty && content.isNotEmpty
        ? '$title\n\n$content'
        : (title.isNotEmpty
            ? title
            : (content.isNotEmpty ? content : 'نوتة فاضية'));
    Share.share(text, subject: title.isNotEmpty ? title : 'نوتة');
  }

  Future<void> _pickSchedule() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? now),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null || !mounted) return;

    setState(() {
      _scheduledTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String get _scheduleLabel {
    if (_scheduledTime == null) return 'جدولة';
    return formatDateTime12(_scheduledTime!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
            icon: const Icon(Icons.arrow_forward, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: TextField(
          controller: _titleController,
          style: GoogleFonts.cairo(
              fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          decoration: InputDecoration(
            hintText: 'العنوان',
            hintStyle:
                GoogleFonts.cairo(fontSize: 22, color: Colors.grey.shade400),
            border: InputBorder.none,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickSchedule,
            icon: Icon(
              Icons.schedule,
              size: 18,
              color: _scheduledTime != null
                  ? const Color(0xFFD4AF37)
                  : Colors.grey.shade600,
            ),
            label: Text(
              _scheduleLabel,
              style: GoogleFonts.cairo(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _scheduledTime != null
                    ? const Color(0xFFD4AF37)
                    : Colors.grey.shade600,
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'share') _shareNote();
              if (value == 'clear_schedule' && _scheduledTime != null) {
                setState(() => _scheduledTime = null);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'share',
                child: Row(children: [
                  const Icon(Icons.share_outlined,
                      color: Colors.black54, size: 22),
                  const SizedBox(width: 10),
                  Text('مشاركة', style: GoogleFonts.cairo(fontSize: 16)),
                ]),
              ),
              if (_scheduledTime != null)
                PopupMenuItem<String>(
                  value: 'clear_schedule',
                  child: Row(children: [
                    const Icon(Icons.close, color: Colors.red, size: 22),
                    const SizedBox(width: 10),
                    Text('إلغاء الجدولة',
                        style: GoogleFonts.cairo(
                            fontSize: 16, color: Colors.red)),
                  ]),
                ),
            ],
          ),
          IconButton(
              icon: const Icon(Icons.check, color: Colors.black, size: 28),
              onPressed: _save),
        ],
      ),
      body: Column(
        children: [
          Container(height: 1, color: Colors.grey.shade200),
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              autofocus: true,
              textAlignVertical: TextAlignVertical.top,
              style: GoogleFonts.cairo(
                  fontSize: 20, height: 1.8, color: Colors.black87),
              decoration: InputDecoration(
                hintText: widget.isFolder
                    ? 'اكتب تفاصيل المجلد هنا...'
                    : 'اكتب مهمتك هنا...',
                hintStyle: GoogleFonts.cairo(
                    fontSize: 20, color: Colors.grey.shade300),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                  top: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('1/1',
                  style: GoogleFonts.cairo(
                      fontSize: 14, color: Colors.grey.shade600)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ==================== Folder Detail ====================

class FolderDetailPage extends StatefulWidget {
  final TaskFolder folder;
  const FolderDetailPage({super.key, required this.folder});
  @override
  State<FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<FolderDetailPage> {
  void _openAddTaskPage() async {
    final result = await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result is AddResult) {
      setState(() => widget.folder.tasks.add(TaskItem(
            title: result.title,
            scheduledTime: result.scheduledTime,
          )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: Text(widget.folder.name,
            style: GoogleFonts.reemKufi(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: widget.folder.tasks.isEmpty
          ? Center(
              child: Text('لسه مفيش مهام، اضغط + للإضافة',
                  style: GoogleFonts.cairo(
                      fontSize: 16, color: Colors.grey.shade500)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.folder.tasks.length,
              itemBuilder: (context, index) {
                final task = widget.folder.tasks[index];
                return TaskCard(
                  task: task,
                  onChanged: () => setState(() {}),
                  onDelete: () {
                    setState(() => widget.folder.tasks.remove(task));
                  },
                );
              },
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 130),
        child: FloatingActionButton(
          onPressed: _openAddTaskPage,
          backgroundColor: Colors.black,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, color: Colors.white, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

// ==================== Profile Page ====================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => ProfilePageState();
}

class ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  late AnimationController _refreshController;

  int totalTasbeeh = 0;
  int uniqueAdhkar = 0;
  String mostUsedDhikr = '—';
  int todayCount = 0;

  int religiousDone = 0;
  int religiousCancelled = 0;
  int religiousNotDone = 0;
  int dailyDone = 0;
  int dailyCancelled = 0;
  int dailyNotDone = 0;

  Map<String, int> dateMap = {};

  @override
  void initState() {
    super.initState();
    _refreshController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> refreshStats() async {
    _refreshController.forward(from: 0);
    setState(() => _isLoading = true);
    await _loadStats();
  }

  Future<void> _loadStats() async {
    final dhikrs = await Storage.loadDhikrEntries();
    final religiousItems = await Storage.loadReligiousItems();
    final dailyItems = await Storage.loadDailyItems();

    int total = 0;
    final Map<String, int> dhikrTotals = {};
    final Map<String, int> dateCounts = {};

    for (final e in dhikrs) {
      total += e.count;
      dhikrTotals[e.dhikr] = (dhikrTotals[e.dhikr] ?? 0) + e.count;
      dateCounts[e.date] = (dateCounts[e.date] ?? 0) + e.count;
    }

    String mostDhikr = '—';
    int mostC = 0;
    dhikrTotals.forEach((k, v) {
      if (v > mostC) {
        mostC = v;
        mostDhikr = k;
      }
    });

    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    int rDone = 0, rNot = 0, rCancel = 0;
    for (final item in religiousItems) {
      if (item is TaskItem) {
        if (item.isDone) {
          rDone++;
        } else if (item.isCancelled) {
          rCancel++;
        } else {
          rNot++;
        }
      } else if (item is TaskFolder) {
        for (final t in item.tasks) {
          if (t.isDone) {
            rDone++;
          } else if (t.isCancelled) {
            rCancel++;
          } else {
            rNot++;
          }
        }
      }
    }

    int dDone = 0, dNot = 0, dCancel = 0;
    for (final item in dailyItems) {
      if (item is TaskItem) {
        if (item.isDone) {
          dDone++;
        } else if (item.isCancelled) {
          dCancel++;
        } else {
          dNot++;
        }
      } else if (item is TaskFolder) {
        for (final t in item.tasks) {
          if (t.isDone) {
            dDone++;
          } else if (t.isCancelled) {
            dCancel++;
          } else {
            dNot++;
          }
        }
      }
    }

    if (!mounted) return;
    setState(() {
      totalTasbeeh = total;
      uniqueAdhkar = dhikrTotals.length;
      mostUsedDhikr = mostDhikr;
      todayCount = dateCounts[todayKey] ?? 0;
      dateMap = dateCounts;
      religiousDone = rDone;
      religiousNotDone = rNot;
      religiousCancelled = rCancel;
      dailyDone = dDone;
      dailyNotDone = dNot;
      dailyCancelled = dCancel;
      _isLoading = false;
    });
  }

  List<MapEntry<String, int>> _last7Days() {
    final now = DateTime.now();
    final result = <MapEntry<String, int>>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      final label = '${d.day}/${d.month}';
      result.add(MapEntry(label, dateMap[key] ?? 0));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('ملفي الشخصي',
            style: GoogleFonts.reemKufi(
                fontWeight: FontWeight.bold, fontSize: 26)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              tooltip: 'تحديث الإحصائيات',
              onPressed: refreshStats,
              icon: RotationTransition(
                turns: _refreshController,
                child: const Icon(Icons.refresh_rounded,
                    color: Color(0xFFD4AF37), size: 26),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFFFAF6EF), Color(0xFFFFF3D4)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFD4AF37),
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFD4AF37)
                                    .withOpacity(0.4),
                                blurRadius: 15)
                          ],
                        ),
                        child: const Icon(Icons.person,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('إحصائياتي',
                                style: GoogleFonts.reemKufi(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text('تابع تقدمك في الطاعة',
                                style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.fingerprint,
                        iconColor: const Color(0xFFD4AF37),
                        value: _toArabicNumber(totalTasbeeh),
                        label: 'إجمالي التسبيح',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        icon: Icons.menu_book,
                        iconColor: Colors.blue,
                        value: _toArabicNumber(uniqueAdhkar),
                        label: 'أذكار مختلفة',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        icon: Icons.star,
                        iconColor: Colors.orange,
                        value: _toArabicNumber(todayCount),
                        label: 'تسبيح النهاردة',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(
                        icon: Icons.favorite,
                        iconColor: Colors.pink,
                        value: mostUsedDhikr.length > 10
                            ? '${mostUsedDhikr.substring(0, 10)}...'
                            : mostUsedDhikr,
                        label: 'الذكر الأكثر',
                        valueSize: mostUsedDhikr.length > 10 ? 14 : 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('📊 آخر ٧ أيام',
                    style: GoogleFonts.reemKufi(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildChart(),
                const SizedBox(height: 20),
                _sectionHeader(
                    icon: Icons.menu_book_rounded,
                    title: 'المهام الدينية',
                    color: const Color(0xFFD4AF37)),
                const SizedBox(height: 10),
                _taskStatsCard(
                  done: religiousDone,
                  notDone: religiousNotDone,
                  cancelled: religiousCancelled,
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 20),
                _sectionHeader(
                    icon: Icons.task_alt_rounded,
                    title: 'المهمات اليومية',
                    color: const Color(0xFFD4AF37)),
                const SizedBox(height: 10),
                _taskStatsCard(
                  done: dailyDone,
                  notDone: dailyNotDone,
                  cancelled: dailyCancelled,
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  String _toArabicNumber(int number) {
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return number
        .toString()
        .split('')
        .map((d) => arabicDigits[int.parse(d)])
        .join();
  }

  Widget _statCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
    double valueSize = 22,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 10),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.reemKufi(
                  fontSize: valueSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.cairo(
                  fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      {required IconData icon,
      required String title,
      required Color color}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.reemKufi(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _taskStatsCard({
    required int done,
    required int notDone,
    required int cancelled,
    required Color color,
  }) {
    final total = done + notDone + cancelled;
    final progress = total == 0 ? 0.0 : done / total;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _taskStatItem(
                  icon: Icons.check_circle,
                  color: Colors.green,
                  value: _toArabicNumber(done),
                  label: 'تم إنجازها',
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade200),
              Expanded(
                child: _taskStatItem(
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                  value: _toArabicNumber(notDone),
                  label: 'لم تُنجز بعد',
                ),
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade200),
              Expanded(
                child: _taskStatItem(
                  icon: Icons.cancel,
                  color: Colors.red,
                  value: _toArabicNumber(cancelled),
                  label: 'متخطّية',
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نسبة الإنجاز',
                      style: GoogleFonts.cairo(
                          fontSize: 12, color: Colors.grey.shade600)),
                  Text('${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: color.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taskStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.reemKufi(
                fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style:
                GoogleFonts.cairo(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildChart() {
    final data = _last7Days();
    final maxVal =
        data.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    final hasData = data.any((e) => e.value > 0);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: !hasData
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 40, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text('لسه مفيش بيانات',
                      style: GoogleFonts.cairo(
                          fontSize: 14, color: Colors.grey.shade500)),
                  Text('ابدأ التسبيح عشان تشوف تقدمك',
                      style: GoogleFonts.cairo(
                          fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: data.map((e) {
                final ratio = e.value / maxVal;
                final barHeight = e.value == 0
                    ? 4.0
                    : (ratio * 100).clamp(8.0, 100.0);
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      e.value == 0 ? '' : _toArabicNumber(e.value),
                      style: GoogleFonts.cairo(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37)),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 22,
                      height: barHeight,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: e.value > 0
                              ? [
                                  const Color(0xFFD4AF37).withOpacity(0.3),
                                  const Color(0xFFD4AF37),
                                ]
                              : [
                                  Colors.grey.shade200,
                                  Colors.grey.shade300,
                                ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: e.value > 0
                            ? [
                                BoxShadow(
                                    color: const Color(0xFFD4AF37)
                                        .withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2))
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(e.key,
                        style: GoogleFonts.cairo(
                            fontSize: 9, color: Colors.grey.shade600)),
                  ],
                );
              }).toList(),
            ),
    );
  }
}

// ==================== Settings Page ====================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _hapticEnabled = true;
  bool _isLoading = true;

  bool _morningEnabled = false;
  TimeOfDay _morningTime = const TimeOfDay(hour: 6, minute: 0);
  bool _eveningEnabled = false;
  TimeOfDay _eveningTime = const TimeOfDay(hour: 17, minute: 0);
  bool _istighfarEnabled = false;
  TimeOfDay _istighfarTime = const TimeOfDay(hour: 12, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final haptic = await Storage.loadHapticEnabled();
    final mE = await Storage.getMorningEnabled();
    final mT = await Storage.getMorningTime();
    final eE = await Storage.getEveningEnabled();
    final eT = await Storage.getEveningTime();
    final iE = await Storage.getIstighfarEnabled();
    final iT = await Storage.getIstighfarTime();
    if (!mounted) return;
    setState(() {
      _hapticEnabled = haptic;
      _morningEnabled = mE;
      _morningTime = mT;
      _eveningEnabled = eE;
      _eveningTime = eT;
      _istighfarEnabled = iE;
      _istighfarTime = iT;
      _isLoading = false;
    });
  }

  Future<void> _toggleHaptic(bool value) async {
    await Storage.saveHapticEnabled(value);
    setState(() => _hapticEnabled = value);
  }

  Future<void> _toggleMorning(bool v) async {
    await Storage.setMorningEnabled(v);
    setState(() => _morningEnabled = v);
    if (v) {
      await NotificationService.scheduleDaily(
        id: kMorningNotifId,
        title: '🌅 أذكار الصباح',
        body: 'صباح الخير! ابدأ يومك بأذكار الصباح',
        hour: _morningTime.hour,
        minute: _morningTime.minute,
      );
    } else {
      await NotificationService.cancel(kMorningNotifId);
    }
  }

  Future<void> _toggleEvening(bool v) async {
    await Storage.setEveningEnabled(v);
    setState(() => _eveningEnabled = v);
    if (v) {
      await NotificationService.scheduleDaily(
        id: kEveningNotifId,
        title: '🌙 أذكار المساء',
        body: 'متنساش أذكار المساء قبل ما تنام',
        hour: _eveningTime.hour,
        minute: _eveningTime.minute,
      );
    } else {
      await NotificationService.cancel(kEveningNotifId);
    }
  }

  Future<void> _toggleIstighfar(bool v) async {
    await Storage.setIstighfarEnabled(v);
    setState(() => _istighfarEnabled = v);
    if (v) {
      await NotificationService.scheduleDaily(
        id: kIstighfarNotifId,
        title: '📿 وقت الاستغفار',
        body: 'خد دقيقة استغفر فيها ربنا',
        hour: _istighfarTime.hour,
        minute: _istighfarTime.minute,
      );
    } else {
      await NotificationService.cancel(kIstighfarNotifId);
    }
  }

  Future<void> _pickTime(TimeOfDay current, Function(TimeOfDay) onPick) async {
    final t = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFD4AF37),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );
    if (t != null) onPick(t);
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline,
                  color: Color(0xFFD4AF37), size: 22),
            ),
            const SizedBox(width: 10),
            Text('حول التطبيق',
                style: GoogleFonts.reemKufi(
                    fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFFFAF6EF), Color(0xFFFFF3D4)],
                ),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.3),
                      blurRadius: 15)
                ],
              ),
              child: const Icon(Icons.mosque,
                  color: Color(0xFFD4AF37), size: 45),
            ),
            const SizedBox(height: 15),
            Text('Istaghfar',
                style: GoogleFonts.reemKufi(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 5),
            Text('الإصدار ١.٠.٠',
                style: GoogleFonts.cairo(
                    fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                    color: const Color(0xFFD4AF37).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('تم إنشاء هذا التطبيق بواسطة',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontSize: 14, color: Colors.grey.shade700)),
                  const SizedBox(height: 8),
                  Text('JK Works',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFD4AF37))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            child: Text('حسناً',
                style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _notificationTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool enabled,
    required TimeOfDay time,
    required ValueChanged<bool> onToggle,
    required VoidCallback onPickTime,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            secondary: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            title: Text(title,
                style: GoogleFonts.cairo(
                    fontSize: 15, fontWeight: FontWeight.bold)),
            subtitle: Text(subtitle,
                style: GoogleFonts.cairo(
                    fontSize: 11, color: Colors.grey.shade600)),
            value: enabled,
            activeColor: const Color(0xFFD4AF37),
            onChanged: onToggle,
          ),
          if (enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.access_time,
                      size: 18, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Text('الوقت:',
                      style: GoogleFonts.cairo(
                          fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onPickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF6EF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                const Color(0xFFD4AF37).withOpacity(0.4)),
                      ),
                      child: Text(formatTime12(time),
                          style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFD4AF37))),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text('الإعدادات',
            style: GoogleFonts.reemKufi(
                fontWeight: FontWeight.bold, fontSize: 26)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader(
                  icon: Icons.tune,
                  title: 'الإعدادات العامة',
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.vibration,
                          color: Color(0xFFD4AF37), size: 22),
                    ),
                    title: Text('اهتزاز عند التسبيح',
                        style: GoogleFonts.cairo(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        _hapticEnabled
                            ? 'مفعّل — هتحس باهتزاز خفيف مع كل ضغطة'
                            : 'متوقف — مش هيحصل اهتزاز',
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: Colors.grey.shade600)),
                    value: _hapticEnabled,
                    activeColor: const Color(0xFFD4AF37),
                    onChanged: _toggleHaptic,
                  ),
                ),
                const SizedBox(height: 25),
                _sectionHeader(
                  icon: Icons.notifications_active,
                  title: 'الإشعارات',
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 10),
                _notificationTile(
                  icon: Icons.wb_sunny,
                  color: Colors.orange,
                  title: 'أذكار الصباح',
                  subtitle: 'تذكير يومي بأذكار الصباح',
                  enabled: _morningEnabled,
                  time: _morningTime,
                  onToggle: _toggleMorning,
                  onPickTime: () => _pickTime(_morningTime, (t) async {
                    setState(() => _morningTime = t);
                    await Storage.setMorningTime(t);
                    if (_morningEnabled) {
                      await NotificationService.scheduleDaily(
                        id: kMorningNotifId,
                        title: '🌅 أذكار الصباح',
                        body: 'صباح الخير! ابدأ يومك بأذكار الصباح',
                        hour: t.hour,
                        minute: t.minute,
                      );
                    }
                  }),
                ),
                _notificationTile(
                  icon: Icons.nights_stay,
                  color: Colors.indigo,
                  title: 'أذكار المساء',
                  subtitle: 'تذكير يومي بأذكار المساء',
                  enabled: _eveningEnabled,
                  time: _eveningTime,
                  onToggle: _toggleEvening,
                  onPickTime: () => _pickTime(_eveningTime, (t) async {
                    setState(() => _eveningTime = t);
                    await Storage.setEveningTime(t);
                    if (_eveningEnabled) {
                      await NotificationService.scheduleDaily(
                        id: kEveningNotifId,
                        title: '🌙 أذكار المساء',
                        body: 'متنساش أذكار المساء قبل ما تنام',
                        hour: t.hour,
                        minute: t.minute,
                      );
                    }
                  }),
                ),
                _notificationTile(
                  icon: Icons.format_quote,
                  color: const Color(0xFFD4AF37),
                  title: 'تذكير بالاستغفار',
                  subtitle: 'تذكير يومي بالاستغفار',
                  enabled: _istighfarEnabled,
                  time: _istighfarTime,
                  onToggle: _toggleIstighfar,
                  onPickTime: () => _pickTime(_istighfarTime, (t) async {
                    setState(() => _istighfarTime = t);
                    await Storage.setIstighfarTime(t);
                    if (_istighfarEnabled) {
                      await NotificationService.scheduleDaily(
                        id: kIstighfarNotifId,
                        title: '📿 وقت الاستغفار',
                        body: 'خد دقيقة استغفر فيها ربنا',
                        hour: t.hour,
                        minute: t.minute,
                      );
                    }
                  }),
                ),
                const SizedBox(height: 25),
                _sectionHeader(
                  icon: Icons.info_outline,
                  title: 'حول',
                  color: const Color(0xFFD4AF37),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8)
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.mosque,
                          color: Color(0xFFD4AF37), size: 22),
                    ),
                    title: Text('حول التطبيق',
                        style: GoogleFonts.cairo(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    subtitle: Text('معلومات عن Istaghfar',
                        style: GoogleFonts.cairo(
                            fontSize: 12, color: Colors.grey.shade600)),
                    trailing: const Icon(Icons.arrow_forward_ios,
                        size: 14, color: Colors.grey),
                    onTap: _showAbout,
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.reemKufi(
                fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
