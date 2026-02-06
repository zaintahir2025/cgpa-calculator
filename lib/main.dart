import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

// PDF & Web Imports
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(MyApp(isDarkMode: isDarkMode));
}

// --- APP CONFIGURATION ---

class MyApp extends StatefulWidget {
  final bool isDarkMode;
  const MyApp({super.key, required this.isDarkMode});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _isDarkMode;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
  }

  void toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Academic CGPA',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      // FORMAL LIGHT THEME
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50), // Formal Navy Blue
          brightness: Brightness.light,
          surface: const Color(0xFFF0F2F5),
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily,
        // Removed global cardTheme to prevent type errors.
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),

      // FORMAL DARK THEME
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C3E50),
          brightness: Brightness.dark,
          surface: const Color(0xFF121212),
        ),
        useMaterial3: true,
        fontFamily: GoogleFonts.roboto().fontFamily,
        inputDecorationTheme: InputDecorationTheme(
          isDense: true,
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
      home: MainScreen(toggleTheme: toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}

// --- MAIN SCREEN (TABS) ---

class MainScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  const MainScreen(
      {super.key, required this.toggleTheme, required this.isDarkMode});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  List<List<Map<String, dynamic>>> semesters = [[]];
  List<String> knownSubjects = [
    'Mathematics',
    'Physics',
    'Programming',
    'English'
  ];
  String degreeName = "";

  Map<String, double> gradePoints = {
    'A': 4.0,
    'A-': 3.7,
    'B+': 3.3,
    'B': 3.0,
    'B-': 2.7,
    'C+': 2.3,
    'C': 2.0,
    'C-': 1.7,
    'D+': 1.3,
    'D': 1.0,
    'F': 0.0
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // --- DATA LOGIC ---
  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('semester_data', jsonEncode(semesters));
    await prefs.setString('grading_scale', jsonEncode(gradePoints));
    await prefs.setStringList('known_subjects', knownSubjects);
    await prefs.setString('degree_name', degreeName);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    String? semData = prefs.getString('semester_data');
    if (semData != null) {
      setState(() {
        Iterable decoded = jsonDecode(semData);
        semesters = List<List<Map<String, dynamic>>>.from(
            decoded.map((s) => List<Map<String, dynamic>>.from(s)));
      });
    }

    String? gradeData = prefs.getString('grading_scale');
    if (gradeData != null) {
      setState(() {
        Map<String, dynamic> decoded = jsonDecode(gradeData);
        gradePoints = decoded
            .map((key, value) => MapEntry(key, (value as num).toDouble()));
      });
    }

    List<String>? subs = prefs.getStringList('known_subjects');
    if (subs != null) {
      setState(() {
        knownSubjects = subs;
      });
    }

    String? degree = prefs.getString('degree_name');
    if (degree != null) {
      setState(() {
        degreeName = degree;
      });
    }
  }

  void updateSemesters(List<List<Map<String, dynamic>>> newSemesters) {
    setState(() {
      semesters = newSemesters;
    });
    _saveData();
  }

  void updateGradingScale(Map<String, double> newScale) {
    setState(() {
      gradePoints = newScale;
    });
    _saveData();
  }

  void updateDegreeName(String newName) {
    setState(() {
      degreeName = newName;
    });
    _saveData();
  }

  void addKnownSubject(String subject) {
    if (!knownSubjects.contains(subject) && subject.isNotEmpty) {
      setState(() {
        knownSubjects.add(subject);
      });
      _saveData();
    }
  }

  // --- CALCULATIONS ---
  double calculateCGPA() {
    double totalPoints = 0.0;
    int totalCredits = 0;
    for (var sem in semesters) {
      for (var sub in sem) {
        int cr = sub['credits'] as int;
        if (gradePoints.containsKey(sub['grade'])) {
          totalPoints += gradePoints[sub['grade']]! * cr;
          totalCredits += cr;
        }
      }
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  int getTotalCredits() {
    int total = 0;
    for (var sem in semesters) {
      for (var sub in sem) {
        total += (sub['credits'] as int);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeTab(
        semesters: semesters,
        gradePoints: gradePoints,
        knownSubjects: knownSubjects,
        onUpdate: updateSemesters,
        onAddSubject: addKnownSubject,
        calculateCGPA: calculateCGPA,
        totalCredits: getTotalCredits(),
      ),
      StatsTab(semesters: semesters, gradePoints: gradePoints),
      AdvisorTab(
        semesters: semesters,
        gradePoints: gradePoints,
        cgpa: calculateCGPA(),
        degreeName: degreeName,
        totalCredits: getTotalCredits(),
      ),
      SimulatorTab(
          currentCGPA: calculateCGPA(),
          currentCredits: getTotalCredits(),
          gradePoints: gradePoints),
      SettingsTab(
        gradePoints: gradePoints,
        onUpdateScale: updateGradingScale,
        toggleTheme: widget.toggleTheme,
        isDarkMode: widget.isDarkMode,
        degreeName: degreeName,
        onUpdateDegree: updateDegreeName,
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('GPA Calculator',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            onPressed: widget.toggleTheme,
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            tooltip: 'Toggle Theme',
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor:
            widget.isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 10,
        shadowColor: Colors.black12,
        indicatorColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calculate_outlined),
              selectedIcon: Icon(Icons.calculate),
              label: 'Calc'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'Stats'),
          NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'Advisor'),
          NavigationDestination(
              icon: Icon(Icons.science_outlined),
              selectedIcon: Icon(Icons.science),
              label: 'Forecast'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 🏠 TAB 1: HOME (CALCULATOR)
// ---------------------------------------------------------------------------

class HomeTab extends StatefulWidget {
  final List<List<Map<String, dynamic>>> semesters;
  final Map<String, double> gradePoints;
  final List<String> knownSubjects;
  final Function(List<List<Map<String, dynamic>>>) onUpdate;
  final Function(String) onAddSubject;
  final double Function() calculateCGPA;
  final int totalCredits;

  const HomeTab(
      {super.key,
      required this.semesters,
      required this.gradePoints,
      required this.onUpdate,
      required this.knownSubjects,
      required this.onAddSubject,
      required this.calculateCGPA,
      required this.totalCredits});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExpanded = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        if (_isFabExpanded) setState(() => _isFabExpanded = false);
      } else {
        if (!_isFabExpanded) setState(() => _isFabExpanded = true);
      }
    });
  }

  Future<void> downloadTranscript() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                  level: 0,
                  child: pw.Text('Academic Transcript',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 20),
              ...widget.semesters.asMap().entries.map((entry) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Semester ${entry.key + 1}',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.TableHelper.fromTextArray(
                      headers: ['Subject', 'Credits', 'Grade'],
                      data: entry.value
                          .map((s) =>
                              [s['name'], s['credits'].toString(), s['grade']])
                          .toList(),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
              pw.Divider(),
              pw.Text(
                  'Overall CGPA: ${widget.calculateCGPA().toStringAsFixed(2)}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    if (kIsWeb) {
      final bytes = await pdf.save();
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'transcript.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
    }
  }

  double _calculateSGPA(List<Map<String, dynamic>> semester) {
    double totalPoints = 0.0;
    int totalCredits = 0;
    for (var sub in semester) {
      int cr = sub['credits'] as int;
      if (widget.gradePoints.containsKey(sub['grade'])) {
        totalPoints += widget.gradePoints[sub['grade']]! * cr;
        totalCredits += cr;
      }
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          _buildTopSummary(context),
          Expanded(
            child: widget.semesters.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (isWideScreen) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 80),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Column(
                                      children: _buildSemesterList(0, 2))),
                              const SizedBox(width: 24),
                              Expanded(
                                  child: Column(
                                      children: _buildSemesterList(1, 2))),
                            ],
                          ),
                        );
                      } else {
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: widget.semesters.length,
                          itemBuilder: (context, index) =>
                              _buildSemesterCard(index),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          widget.semesters.add([]);
          widget.onUpdate(widget.semesters);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
            }
          });
        },
        isExtended: _isFabExpanded,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Semester'),
      ),
    );
  }

  List<Widget> _buildSemesterList(int start, int step) {
    List<Widget> items = [];
    for (int i = start; i < widget.semesters.length; i += step) {
      items.add(_buildSemesterCard(i));
    }
    return items;
  }

  Widget _buildTopSummary(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border:
            Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Row(
            children: [
              _summaryItem(context, "CGPA",
                  widget.calculateCGPA().toStringAsFixed(2), true),
              const SizedBox(width: 40),
              _summaryItem(
                  context, "CREDITS", widget.totalCredits.toString(), false),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: downloadTranscript,
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text("Export"),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(
      BuildContext context, String label, String value, bool isPrimary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).hintColor,
                letterSpacing: 1.0)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: isPrimary
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodyLarge?.color)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_outlined,
              size: 64, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text("No semesters added yet",
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text("Start by clicking the button below",
              style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(int index) {
    final sgpa = _calculateSGPA(widget.semesters[index]);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('SEMESTER ${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        letterSpacing: 0.8)),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('SGPA: ${sgpa.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        widget.semesters.removeAt(index);
                        widget.onUpdate(widget.semesters);
                      },
                      child:
                          const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 40, 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('COURSE', style: _labelStyle())),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: Text('CR', style: _labelStyle())),
                const SizedBox(width: 8),
                Expanded(flex: 1, child: Text('GR', style: _labelStyle())),
              ],
            ),
          ),
          const Divider(height: 1),
          ...widget.semesters[index]
              .asMap()
              .entries
              .map((entry) => _buildSubjectRow(index, entry.key, entry.value)),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  widget.semesters[index].add({
                    'name': '',
                    'credits': 3,
                    'grade': widget.gradePoints.keys.first
                  });
                  widget.onUpdate(widget.semesters);
                },
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Add Course'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle() {
    return TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).hintColor,
        letterSpacing: 0.5);
  }

  Widget _buildSubjectRow(
      int semIndex, int subIndex, Map<String, dynamic> subject) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                return widget.knownSubjects.where((String option) => option
                    .toLowerCase()
                    .contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (String selection) {
                subject['name'] = selection;
                widget.onUpdate(widget.semesters);
              },
              fieldViewBuilder:
                  (context, textController, focusNode, onFieldSubmitted) {
                if (textController.text != subject['name']) {
                  textController.text = subject['name'];
                }
                return TextFormField(
                  controller: textController,
                  focusNode: focusNode,
                  onChanged: (v) {
                    subject['name'] = v;
                    widget.onUpdate(widget.semesters);
                  },
                  onFieldSubmitted: (v) => widget.onAddSubject(v),
                  decoration: const InputDecoration(hintText: 'Course Name'),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: TextFormField(
              initialValue: subject['credits'].toString(),
              keyboardType: TextInputType.number,
              onChanged: (val) {
                subject['credits'] = int.tryParse(val) ?? 0;
                widget.onUpdate(widget.semesters);
              },
              decoration: const InputDecoration(hintText: '3'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              initialValue: widget.gradePoints.containsKey(subject['grade'])
                  ? subject['grade']
                  : widget.gradePoints.keys.first,
              items: widget.gradePoints.keys
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (val) {
                subject['grade'] = val;
                widget.onUpdate(widget.semesters);
              },
              decoration: const InputDecoration(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: Colors.red.shade200,
            onPressed: () {
              widget.semesters[semIndex].removeAt(subIndex);
              widget.onUpdate(widget.semesters);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 📊 TAB 2: STATS
// ---------------------------------------------------------------------------

class StatsTab extends StatelessWidget {
  final List<List<Map<String, dynamic>>> semesters;
  final Map<String, double> gradePoints;

  const StatsTab(
      {super.key, required this.semesters, required this.gradePoints});

  @override
  Widget build(BuildContext context) {
    if (semesters.isEmpty) {
      return Center(
          child: Text("Add semesters to view trends.",
              style: TextStyle(color: Colors.grey.shade500)));
    }

    List<BarChartGroupData> barGroups = [];
    double maxGpa = 4.0;

    for (int i = 0; i < semesters.length; i++) {
      double sgpa = _calculateSGPA(semesters[i]);
      barGroups.add(
        BarChartGroupData(
          x: i + 1,
          barRods: [
            BarChartRodData(
              toY: sgpa,
              color: Theme.of(context).colorScheme.primary,
              width: 32,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxGpa,
                  color: Colors.grey.withValues(alpha: 0.1)),
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("PERFORMANCE HISTORY",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 30),
                  Expanded(
                    child: BarChart(
                      BarChartData(
                        maxY: maxGpa,
                        alignment: BarChartAlignment.spaceAround,
                        barGroups: barGroups,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            tooltipPadding: const EdgeInsets.all(12),
                            tooltipMargin: 8,
                            fitInsideHorizontally: true,
                            fitInsideVertically: true,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.toStringAsFixed(2)} GPA',
                                const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, _) => Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text('Sem ${val.toInt()}',
                                          style:
                                              const TextStyle(fontSize: 12))))),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  getTitlesWidget: (val, _) => Text(
                                      val.toInt().toString(),
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey)))),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (val) => FlLine(
                                color: Colors.grey.withValues(alpha: 0.1),
                                strokeWidth: 1)),
                        borderData: FlBorderData(show: false),
                      ),
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

  double _calculateSGPA(List<Map<String, dynamic>> semester) {
    double totalPoints = 0.0;
    int totalCredits = 0;
    for (var sub in semester) {
      int cr = sub['credits'] as int;
      if (gradePoints.containsKey(sub['grade'])) {
        totalPoints += gradePoints[sub['grade']]! * cr;
        totalCredits += cr;
      }
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }
}

// ---------------------------------------------------------------------------
// 🧠 TAB 3: ADVISOR (INTELLIGENT ANALYSIS) - NEW & IMPROVED
// ---------------------------------------------------------------------------

class AdvisorTab extends StatelessWidget {
  final List<List<Map<String, dynamic>>> semesters;
  final Map<String, double> gradePoints;
  final double cgpa;
  final String degreeName;
  final int totalCredits;

  const AdvisorTab(
      {super.key,
      required this.semesters,
      required this.gradePoints,
      required this.cgpa,
      required this.degreeName,
      required this.totalCredits});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Analyze Subjects
    List<Map<String, dynamic>> allSubjects = [];
    for (var sem in semesters) {
      allSubjects.addAll(sem);
    }

    // 1. Filter: Find Improveable Subjects (Grade points <= 2.0 i.e., C or lower)
    List<Map<String, dynamic>> subjectsToImprove = allSubjects.where((s) {
      double points = gradePoints[s['grade']] ?? 0.0;
      return points <=
          2.0; // Specifically defined low grade threshold (C and below)
    }).toList();

    // 2. Sort by "Potential Impact"
    // Impact = (4.0 - CurrentGrade) * Credits.
    // This prioritizes retaking a 4-credit 'F' over a 1-credit 'D'.
    subjectsToImprove.sort((a, b) {
      double pA = gradePoints[a['grade']] ?? 0;
      double pB = gradePoints[b['grade']] ?? 0;
      int cA = a['credits'] as int;
      int cB = b['credits'] as int;

      double impactA = (4.0 - pA) * cA;
      double impactB = (4.0 - pB) * cB;

      return impactB.compareTo(impactA); // Descending order
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, "STRATEGIC IMPROVEMENTS"),
              const SizedBox(height: 16),
              if (semesters.isEmpty)
                const Card(
                    child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text("Add subjects to generate analysis.")))
              else if (subjectsToImprove.isEmpty)
                Card(
                    elevation: 0,
                    color: Colors.green.withValues(alpha: 0.1),
                    child: const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    "No critical improvements needed. Your grades are solid!",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                          ],
                        )))
              else
                ...subjectsToImprove
                    .map((s) => _buildImprovementCard(context, s)),
              const SizedBox(height: 32),
              _buildSectionHeader(context, "CAREER ROADMAP"),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.work_outline,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              degreeName.isEmpty
                                  ? "No Degree Specified"
                                  : "Path: $degreeName",
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      Text(
                        _getCareerAdvice(degreeName, cgpa),
                        style: const TextStyle(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(title,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Theme.of(context).hintColor));
  }

  Widget _buildImprovementCard(
      BuildContext context, Map<String, dynamic> subject) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    double currentPoints = gradePoints[subject['grade']] ?? 0.0;
    int credits = subject['credits'];
    bool isHighCredits = credits >= 3;
    bool isFieldImportant = _isSubjectImportant(subject['name'], degreeName);

    // Determine Urgency
    Color statusColor = Colors.blue;
    String recommendation = "Optional improvement.";

    if (isFieldImportant && currentPoints < 1.0) {
      statusColor = Colors.red;
      recommendation =
          "CRITICAL: This is a core field subject. You must retake it.";
    } else if (isHighCredits && currentPoints <= 1.7) {
      statusColor = Colors.orange;
      recommendation =
          "High Impact: Retaking this 3+ credit course will significantly boost CGPA.";
    } else if (currentPoints == 0.0) {
      statusColor = Colors.red;
      recommendation = "Mandatory: You must clear this F grade.";
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                    child: Text(subject['name'],
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text("${subject['grade']} ($credits Cr)",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Text(recommendation,
                style: TextStyle(
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  bool _isSubjectImportant(String subjectName, String degree) {
    if (degree.isEmpty) return false;
    // Simple heuristic: If words from the degree title appear in the subject title
    List<String> degreeKeywords =
        degree.toLowerCase().split(' ').where((w) => w.length > 2).toList();
    String subj = subjectName.toLowerCase();

    for (String word in degreeKeywords) {
      if (subj.contains(word)) return true;
    }
    return false;
  }

  String _getCareerAdvice(String degree, double cgpa) {
    if (degree.isEmpty) {
      return "Please go to Settings and enter your Degree Name to receive tailored career advice.";
    }

    String advice = "";

    // General Strategy based on GPA
    if (cgpa >= 3.5) {
      advice +=
          "🌟 Excellent Academic Standing.\nYour high GPA qualifies you for R&D roles, top-tier graduate schools, and competitive management trainee programs. Focus on maintaining this while publishing research or leading student chapters.\n\n";
    } else if (cgpa >= 3.0) {
      advice +=
          "🚀 Solid Performance.\nYou are in a safe zone for most industry jobs. To stand out, prioritize practical internships and hands-on projects. Your skills will matter more than the slight difference in GPA.\n\n";
    } else {
      advice +=
          "⚠️ Focus on Skills.\nYour GPA might be a filter for some large corporations. Counter this by building a rock-solid portfolio. Certifications, freelance work, and personal projects are your best friends right now.\n\n";
    }

    // Degree Specifics
    String d = degree.toLowerCase();
    if (d.contains("computer") ||
        d.contains("software") ||
        d.contains("it") ||
        d.contains("cs")) {
      advice +=
          "💻 Tech Specific:\n- Build a GitHub portfolio.\n- Practice LeetCode for technical interviews.\n- Contribute to Open Source.\n- Focus on Data Structures if you want backend roles.";
    } else if (d.contains("business") ||
        d.contains("bba") ||
        d.contains("management")) {
      advice +=
          "📈 Business Specific:\n- Network on LinkedIn.\n- Look for internships in operations or marketing.\n- Obtain certifications like PMP or Google Analytics.";
    } else if (d.contains("engineer")) {
      advice +=
          "⚙️ Engineering Specific:\n- Focus on lab skills and CAD tools.\n- Aim for internships in manufacturing or design firms.";
    } else {
      advice +=
          "🎓 General Advice:\n- Networking is key in your field.\n- Look for mentors and attend industry seminars.";
    }

    return advice;
  }
}

// ---------------------------------------------------------------------------
// 🔮 TAB 4: SIMULATOR (FORECAST)
// ---------------------------------------------------------------------------

class SimulatorTab extends StatefulWidget {
  final double currentCGPA;
  final int currentCredits;
  final Map<String, double> gradePoints;

  const SimulatorTab(
      {super.key,
      required this.currentCGPA,
      required this.currentCredits,
      required this.gradePoints});

  @override
  State<SimulatorTab> createState() => _SimulatorTabState();
}

class _SimulatorTabState extends State<SimulatorTab> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _totalCreditsController = TextEditingController();
  String _result = "";

  void _calculateTarget() {
    double target = double.tryParse(_targetController.text) ?? 0.0;
    int totalDegreeCredits = int.tryParse(_totalCreditsController.text) ?? 130;
    int remainingCredits = totalDegreeCredits - widget.currentCredits;

    if (remainingCredits <= 0) {
      setState(() {
        _result = "No remaining credits to improve GPA.";
      });
      return;
    }

    double currentPoints = widget.currentCGPA * widget.currentCredits;
    double requiredTotalPoints = target * totalDegreeCredits;
    double pointsNeeded = requiredTotalPoints - currentPoints;
    double requiredGPA = pointsNeeded / remainingCredits;
    double maxGPA = widget.gradePoints.values.reduce(math.max);

    setState(() {
      if (requiredGPA > maxGPA) {
        _result =
            "Target unreachable. Max possible GPA on remaining credits: ${((currentPoints + (maxGPA * remainingCredits)) / totalDegreeCredits).toStringAsFixed(2)}";
      } else if (requiredGPA < 0) {
        _result = "You have already achieved this target.";
      } else {
        _result =
            "Required Average GPA: ${requiredGPA.toStringAsFixed(2)} in next $remainingCredits credits.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("FORECAST",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color:
                          isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Current CGPA",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(widget.currentCGPA.toStringAsFixed(2),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold))
                          ]),
                      Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey.withValues(alpha: 0.2)),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Credits Earned",
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(widget.currentCredits.toString(),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold))
                          ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                  controller: _targetController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Target CGPA', hintText: 'e.g. 3.5')),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _totalCreditsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Total Degree Credits', hintText: 'e.g. 130')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _calculateTarget,
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  child: const Text("CALCULATE"),
                ),
              ),
              const SizedBox(height: 24),
              if (_result.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3))),
                  child: Text(_result,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600)),
                )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ⚙️ TAB 5: SETTINGS (FORMAL)
// ---------------------------------------------------------------------------

class SettingsTab extends StatelessWidget {
  final Map<String, double> gradePoints;
  final Function(Map<String, double>) onUpdateScale;
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  final String degreeName;
  final Function(String) onUpdateDegree;

  const SettingsTab(
      {super.key,
      required this.gradePoints,
      required this.onUpdateScale,
      required this.toggleTheme,
      required this.isDarkMode,
      required this.degreeName,
      required this.onUpdateDegree});

  void _editGrade(BuildContext context, String? oldLetter, double? oldVal) {
    String letter = oldLetter ?? "";
    String val = oldVal?.toString() ?? "";
    TextEditingController lCtrl = TextEditingController(text: letter);
    TextEditingController vCtrl = TextEditingController(text: val);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(oldLetter == null ? "Add Grade" : "Edit Grade"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: lCtrl,
              decoration: const InputDecoration(labelText: "Letter")),
          const SizedBox(height: 10),
          TextField(
              controller: vCtrl,
              decoration: const InputDecoration(labelText: "Points"),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true))
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
              onPressed: () {
                // FIXED: Read directly from controllers to ensure latest input is captured
                String currentLetter = lCtrl.text.trim();
                String currentVal = vCtrl.text.trim();

                if (currentLetter.isNotEmpty && currentVal.isNotEmpty) {
                  Map<String, double> newMap = Map.from(gradePoints);
                  if (oldLetter != null && oldLetter != currentLetter) {
                    newMap.remove(oldLetter);
                  }
                  newMap[currentLetter] = double.tryParse(currentVal) ?? 0.0;
                  onUpdateScale(newMap);
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Save")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var sortedKeys = gradePoints.keys.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text("ACADEMIC PROFILE",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Degree Title",
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: degreeName,
                      onChanged: onUpdateDegree,
                      decoration: const InputDecoration(
                          hintText: "e.g. BS Computer Science",
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text("APP PREFERENCES",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 20),
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300)),
              child: ListTile(
                  title: const Text("Dark Mode"),
                  trailing: Switch(
                      value: isDarkMode, onChanged: (v) => toggleTheme())),
            ),
            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("GRADING SCALE",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2)),
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _editGrade(context, null, null))
            ]),
            const SizedBox(height: 10),
            ...sortedKeys.map((key) => Card(
                elevation: 0,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                    title: Text(key,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: SizedBox(
                        width: 120,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(gradePoints[key].toString()),
                              const SizedBox(width: 10),
                              IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _editGrade(
                                      context, key, gradePoints[key])),
                              IconButton(
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Colors.red),
                                  onPressed: () {
                                    Map<String, double> newMap =
                                        Map.from(gradePoints);
                                    newMap.remove(key);
                                    onUpdateScale(newMap);
                                  })
                            ]))))),
          ],
        ),
      ),
    );
  }
}
