import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

void main() {
  runApp(const IstaghfirApp());
}

const List<String> kStandardDhikrs = [
  'سُبْحَانَ الله',
  'لَا إِلَهَ إِلَّا الله',
  'أَسْتَغْفِرُ اللهَ العَظِيمَ وَأَتُوبُ إِلَيْه',
];

class IstaghfirApp extends StatelessWidget {
  const IstaghfirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إستَغفِر',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.cairoTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E63)),
      ),
      home: const MainScreen(),
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
          'name': item.name,
          'tasks': item.tasks
              .map((t) => {'title': t.title, 'isDone': t.isDone})
              .toList(),
        };
      } else if (item is TaskItem) {
        return {'type': 'task', 'title': item.title, 'isDone': item.isDone};
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
              .map((t) =>
                  TaskItem(title: t['title'], isDone: t['isDone'] ?? false))
              .toList();
          return TaskFolder(name: item['name'], tasks: tasks);
        } else {
          return TaskItem(
              title: item['title'], isDone: item['isDone'] ?? false);
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

  // ✅ إعدادات الاهتزاز
  static Future<bool> loadHapticEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hapticKey) ?? true;
  }

  static Future<void> saveHapticEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hapticKey, value);
  }
}

// ==================== Models ====================

class TaskItem {
  String title;
  bool isDone;
  TaskItem({required this.title, this.isDone = false});
}

class TaskFolder {
  String name;
  List<TaskItem> tasks;
  TaskFolder({required this.name, List<TaskItem>? tasks})
      : tasks = tasks ?? [];
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

// ==================== MainScreen ====================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
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
      const ProfilePage(),
      const SettingsPage(),
    ];

    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        reverse: true,
        onPageChanged: (index) => setState(() => _currentIndex = index),
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

class HomePage extends StatelessWidget {
  final VoidCallback onReligiousTasksTap;
  final VoidCallback onDailyTasksTap;
  const HomePage(
      {super.key,
      required this.onReligiousTasksTap,
      required this.onDailyTasksTap});

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
                onTap: onReligiousTasksTap,
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
              onTap: onDailyTasksTap,
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

  // ✅ الاهتزاز بيحصل بس لو الإعداد مفعّل
  Future<void> _increment() async {
    final hapticEnabled = await Storage.loadHapticEnabled();
    if (hapticEnabled) {
      HapticFeedback.lightImpact();
    }
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
    final dateStr = '${now.day}/${now.month}/${now.year}';
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
                                    child: Text(
                                      _currentDhikr,
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.amiri(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700),
                                    ),
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
    final loaded = await Storage.loadReligiousItems();
    final dhikrs = await Storage.loadDhikrEntries();
    setState(() {
      items = loaded;
      dhikrEntries = dhikrs;
      _isLoading = false;
    });
  }

  Future<void> _save() async => await Storage.saveReligiousItems(items);

  void _openAddTaskPage() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result.toString().isNotEmpty) {
      setState(() => items.add(TaskItem(title: result.toString())));
      _save();
    }
  }

  void _openAddFolderPage() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(
            builder: (context) => const AddTaskPage(isFolder: true)));
    if (result != null && result.toString().isNotEmpty) {
      setState(() => items.add(TaskFolder(name: result.toString())));
      _save();
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إضافة جديدة',
                style: GoogleFonts.reemKufi(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.folder_rounded, color: Colors.blue),
              ),
              title: Text('مجلد جديد (نوتة)',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              subtitle: Text('لتجميع المهام في مكان واحد',
                  style: GoogleFonts.cairo(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openAddFolderPage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
              ),
              title: Text('مهمة سريعة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              subtitle: Text('مهمة مباشرة من غير مجلد',
                  style: GoogleFonts.cairo(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openAddTaskPage();
              },
            ),
          ],
        ),
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
                                  'العدد: ${e.count}  •  ${e.date}',
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
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.folder_rounded, color: Colors.blue),
          ),
          title: Text(item.name,
              style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text('${item.tasks.length} مهمة',
              style: GoogleFonts.cairo()),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () {
            Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => FolderDetailPage(folder: item)))
                .then((_) {
              setState(() {});
              _save();
            });
          },
        ),
      );
    } else if (item is TaskItem) {
      return TaskCard(
        task: item,
        onToggle: (val) {
          setState(() => item.isDone = val);
          _save();
        },
      );
    }
    return const SizedBox.shrink();
  }
}

// ==================== Task Card ====================

class TaskCard extends StatelessWidget {
  final TaskItem task;
  final ValueChanged<bool> onToggle;
  const TaskCard({super.key, required this.task, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => onToggle(!task.isDone),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () => onToggle(!task.isDone),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: task.isDone
                        ? const Color(0xFFD4AF37)
                        : Colors.transparent,
                    border: Border.all(
                        color: task.isDone
                            ? const Color(0xFFD4AF37)
                            : Colors.grey.shade400,
                        width: 2),
                  ),
                  child: task.isDone
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 16)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title,
                  style: GoogleFonts.cairo(
                    decoration: task.isDone
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.isDone ? Colors.grey : Colors.black,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: task.isDone
                    ? const Icon(Icons.check_circle,
                        color: Colors.green, size: 22)
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.orange.shade200),
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
    final loaded = await Storage.loadDailyItems();
    setState(() {
      items = loaded;
      _isLoading = false;
    });
  }

  Future<void> _save() async => await Storage.saveDailyItems(items);

  void _openAddTaskPage() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result.toString().isNotEmpty) {
      setState(() => items.add(TaskItem(title: result.toString())));
      _save();
    }
  }

  void _openAddFolderPage() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(
            builder: (context) => const AddTaskPage(isFolder: true)));
    if (result != null && result.toString().isNotEmpty) {
      setState(() => items.add(TaskFolder(name: result.toString())));
      _save();
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('إضافة جديدة',
                style: GoogleFonts.reemKufi(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.folder_rounded, color: Colors.blue),
              ),
              title: Text('مجلد جديد (نوتة)',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              subtitle: Text('لتجميع المهام في مكان واحد',
                  style: GoogleFonts.cairo(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openAddFolderPage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.check_circle_outline,
                    color: Colors.green),
              ),
              title: Text('مهمة سريعة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              subtitle: Text('مهمة مباشرة من غير مجلد',
                  style: GoogleFonts.cairo(fontSize: 12)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openAddTaskPage();
              },
            ),
          ],
        ),
      ),
    );
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.folder_rounded,
                                color: Colors.blue),
                          ),
                          title: Text(item.name,
                              style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('${item.tasks.length} مهمة',
                              style: GoogleFonts.cairo()),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () {
                            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            FolderDetailPage(folder: item)))
                                .then((_) {
                              setState(() {});
                              _save();
                            });
                          },
                        ),
                      );
                    } else if (item is TaskItem) {
                      return TaskCard(
                        task: item,
                        onToggle: (val) {
                          setState(() => item.isDone = val);
                          _save();
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

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    String result = '';
    if (title.isNotEmpty && content.isNotEmpty) {
      result = '$title\n$content';
    } else if (title.isNotEmpty) {
      result = title;
    } else if (content.isNotEmpty) {
      result = content;
    }
    if (result.isNotEmpty) Navigator.pop(context, result);
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              if (value == 'share') _shareNote();
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'share',
                child: Row(children: [
                  const Icon(Icons.share_outlined,
                      color: Colors.black54, size: 22),
                  const SizedBox(width: 10),
                  Text('مشاركة',
                      style: GoogleFonts.cairo(
                          fontSize: 16, color: Colors.black87)),
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
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result.toString().isNotEmpty) {
      setState(
          () => widget.folder.tasks.add(TaskItem(title: result.toString())));
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
                  onToggle: (val) => setState(() => task.isDone = val),
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
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;

  int totalTasbeeh = 0;
  int uniqueAdhkar = 0;
  String mostUsedDhikr = '—';
  int todayCount = 0;

  int religiousDone = 0;
  int religiousNotDone = 0;
  int dailyDone = 0;
  int dailyNotDone = 0;

  Map<String, int> dateMap = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
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
    final todayStr = '${now.day}/${now.month}/${now.year}';

    int rDone = 0, rNot = 0;
    for (final item in religiousItems) {
      if (item is TaskItem) {
        if (item.isDone) {
          rDone++;
        } else {
          rNot++;
        }
      } else if (item is TaskFolder) {
        for (final t in item.tasks) {
          if (t.isDone) {
            rDone++;
          } else {
            rNot++;
          }
        }
      }
    }

    int dDone = 0, dNot = 0;
    for (final item in dailyItems) {
      if (item is TaskItem) {
        if (item.isDone) {
          dDone++;
        } else {
          dNot++;
        }
      } else if (item is TaskFolder) {
        for (final t in item.tasks) {
          if (t.isDone) {
            dDone++;
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
      todayCount = dateCounts[todayStr] ?? 0;
      dateMap = dateCounts;
      religiousDone = rDone;
      religiousNotDone = rNot;
      dailyDone = dDone;
      dailyNotDone = dNot;
      _isLoading = false;
    });
  }

  List<MapEntry<String, int>> _last7Days() {
    final now = DateTime.now();
    final result = <MapEntry<String, int>>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.day}/${d.month}/${d.year}';
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
    required Color color,
  }) {
    final total = done + notDone;
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
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.reemKufi(
                fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style:
                GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildChart() {
    final data = _last7Days();
    final maxVal =
        data.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: data.map((e) {
          final ratio = e.value / maxVal;
          final barHeight = (ratio * 100).clamp(4.0, 100.0);
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
                    colors: [
                      const Color(0xFFD4AF37).withOpacity(0.3),
                      const Color(0xFFD4AF37),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: e.value > 0
                      ? [
                          BoxShadow(
                              color: const Color(0xFFD4AF37).withOpacity(0.4),
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await Storage.loadHapticEnabled();
    if (!mounted) return;
    setState(() {
      _hapticEnabled = enabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleHaptic(bool value) async {
    await Storage.saveHapticEnabled(value);
    setState(() => _hapticEnabled = value);
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
            Text('إستَغفِر',
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
                  Text('@JOKERICH',
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
                    subtitle: Text('معلومات عن إستَغفِر',
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
