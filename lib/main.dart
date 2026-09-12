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
  static const String _religiousKey = 'religious_tasks_v1';
  static const String _dhikrKey = 'dhikr_entries_v1';

  static Future<void> saveDailyItems(List<dynamic> items) async {
    final prefs = await SharedPreferences.getInstance();
    final data = items.map((item) {
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
    await prefs.setString(_dailyKey, jsonEncode(data));
  }

  static Future<List<dynamic>> loadDailyItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyKey);
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

  static Future<void> saveReligiousTasks(List<TaskItem> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final data =
        tasks.map((t) => {'title': t.title, 'isDone': t.isDone}).toList();
    await prefs.setString(_religiousKey, jsonEncode(data));
  }

  static Future<List<TaskItem>> loadReligiousTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_religiousKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final data = jsonDecode(raw) as List;
      return data
          .map((t) =>
              TaskItem(title: t['title'], isDone: t['isDone'] ?? false))
          .toList();
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

  void _openReligiousTasks() {
    Navigator.push(context,
        MaterialPageRoute(builder: (context) => const ReligiousTasksPage()));
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
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
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
                                        ? Colors.red
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0),
            child: Icon(Icons.circle_outlined,
                size: 40, color: Colors.grey.shade600),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () async {
                final dhikr = await DhikrSelectionDialog.show(context);
                if (dhikr != null && context.mounted) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TasbeehPage(dhikr: dhikr)));
                }
              },
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
  static Future<String?> show(BuildContext context) async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: const Color(0xFFFAF6EF),
        title: Text('هَتَقُول إيه؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.amiri(
                fontSize: 26, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _option(context, 'سُبْحَانَ الله'),
            _option(context, 'لَا إِلَهَ إِلَّا الله'),
            _option(context, 'أَسْتَغْفِرُ اللهَ العَظِيمَ وَأَتُوبُ إِلَيْه'),
            _option(context, 'دُعَاء تَانِي', isSpecial: true),
          ],
        ),
      ),
    );
  }

  static Widget _option(BuildContext context, String text,
      {bool isSpecial = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            if (isSpecial) {
              Navigator.pop(context);
              _showCustomDhikr(context);
            } else {
              Navigator.pop(context, text);
            }
          },
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

  static Future<void> _showCustomDhikr(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
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
              onTap: () => Navigator.pop(context, 'write'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward, color: Colors.grey),
              title: Text('كمل من غير حاجة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context, 'skip'),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == 'write') {
      final text = await _showWriteDialog(context);
      if (text != null && text.isNotEmpty && context.mounted) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => TasbeehPage(dhikr: text)));
      }
    } else if (result == 'skip') {
      Navigator.push(context,
          MaterialPageRoute(builder: (context) => const TasbeehPage(dhikr: '')));
    }
  }

  static Future<String?> _showWriteDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('اكتب الدعاء', style: GoogleFonts.amiri(fontWeight: FontWeight.bold, fontSize: 22)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: GoogleFonts.amiri(fontSize: 18),
          decoration: const InputDecoration(
              hintText: 'مثلاً: اللهم صل على محمد'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo())),
          TextButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: Text('موافق',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold))),
        ],
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

  int get litCount {
    if (count == 0) return 0;
    return ((count - 1) % totalCircles) + 1;
  }

  void _increment() {
    HapticFeedback.lightImpact();
    setState(() {
      count++;
      _scale = 1.08;
    });
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _scale = 1.0);
    });
  }

  void _showSaveOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                Navigator.pop(context);
                _saveCount();
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: Text('تبدأ من جديد',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
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
    final dhikrName = widget.dhikr.isEmpty ? 'ذكر حر' : widget.dhikr;
    await Storage.saveDhikrEntry(
        DhikrEntry(dhikr: dhikrName, count: count, date: dateStr));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم حفظ العدد في ملف في المهام الدينية ✓',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
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
        title: Text(widget.dhikr.isEmpty ? 'سُبْحَة' : widget.dhikr,
            style: GoogleFonts.amiri(
                fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
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
                                Text('$count',
                                    style: GoogleFonts.cairo(
                                        fontSize: 62,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                        height: 1)),
                                if (widget.dhikr.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Text(
                                      widget.dhikr,
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
  List<TaskItem> religiousTasks = [];
  List<DhikrEntry> dhikrEntries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final tasks = await Storage.loadReligiousTasks();
    final dhikrs = await Storage.loadDhikrEntries();
    setState(() {
      religiousTasks = tasks;
      dhikrEntries = dhikrs;
      _isLoading = false;
    });
  }

  Future<void> _save() async =>
      await Storage.saveReligiousTasks(religiousTasks);

  void _openAddTaskPage() async {
    final result = await Navigator.push(context,
        MaterialPageRoute(builder: (context) => const AddTaskPage()));
    if (result != null && result.toString().isNotEmpty) {
      setState(() => religiousTasks.add(TaskItem(title: result.toString())));
      _save();
    }
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
          : (religiousTasks.isEmpty && dhikrEntries.isEmpty)
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
                      Text('اضغط على + عشان تضيف مهمة',
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
                    if (religiousTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text('✓ المهام',
                            style: GoogleFonts.reemKufi(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      ...religiousTasks.asMap().entries.map((entry) {
                        final task = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          child: CheckboxListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            title: Text(task.title,
                                style: GoogleFonts.cairo(
                                  decoration: task.isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: task.isDone
                                      ? Colors.grey
                                      : Colors.black,
                                )),
                            value: task.isDone,
                            activeColor: Colors.green,
                            onChanged: (val) {
                              setState(() => task.isDone = val ?? false);
                              _save();
                            },
                          ),
                        );
                      }),
                    ],
                  ],
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
        MaterialPageRoute(builder: (context) => const AddTaskPage(isFolder: true)));
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
      builder: (context) => Padding(
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
                Navigator.pop(context);
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
                Navigator.pop(context);
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
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 14),
                          onTap: () {
                            Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => FolderDetailPage(
                                            folder: item)))
                                .then((_) {
                              setState(() {});
                              _save();
                            });
                          },
                        ),
                      );
                    } else if (item is TaskItem) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15)),
                        child: CheckboxListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          title: Text(item.title,
                              style: GoogleFonts.cairo(
                                decoration: item.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isDone
                                    ? Colors.grey
                                    : Colors.black,
                              )),
                          value: item.isDone,
                          activeColor: Colors.green,
                          onChanged: (val) {
                            setState(() => item.isDone = val ?? false);
                            _save();
                          },
                        ),
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
        : (title.isNotEmpty ? title : (content.isNotEmpty ? content : 'نوتة فاضية'));
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
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: CheckboxListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    title: Text(task.title,
                        style: GoogleFonts.cairo(
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : null,
                          color:
                              task.isDone ? Colors.grey : Colors.black,
                        )),
                    value: task.isDone,
                    activeColor: Colors.green,
                    onChanged: (val) =>
                        setState(() => task.isDone = val ?? false),
                  ),
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

// ==================== Empty Pages ====================

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('صفحة الملف الشخصي'));
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('صفحة الإعدادات'));
}
