import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  runApp(MyApp(isDarkMode: isDarkMode));
}

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
      title: 'CGPA Calculator',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CGPACalculator(
        toggleTheme: toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}

class CGPACalculator extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;
  const CGPACalculator({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  CGPACalculatorState createState() => CGPACalculatorState();
}

class CGPACalculatorState extends State<CGPACalculator> {
  List<List<Map<String, dynamic>>> semesters = [[]];
  int maxSemesters = 8;

  Map<String, double> gradePoints = {
    'A': 4.0,
    'A-': 3.7,
    'B+': 3.3,
    'B': 3.0,
    'B-': 2.7,
    'C+': 2.3,
    'C': 2.0,
    'D': 1.0,
    'F': 0.0
  };

  void addSemester() {
    if (semesters.length < maxSemesters) {
      setState(() {
        semesters.add([]);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum number of semesters reached')),
      );
    }
  }

  void addSubject(int semesterIndex) {
    setState(() {
      semesters[semesterIndex].add({'name': '', 'credits': 0, 'grade': 'A'});
    });
  }

  void removeSubject(int semesterIndex, int subjectIndex) {
    setState(() {
      semesters[semesterIndex].removeAt(subjectIndex);
    });
  }

  void removeSemester(int semesterIndex) {
    if (semesters.length > 1) {
      setState(() {
        semesters.removeAt(semesterIndex);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must have at least one semester')),
      );
    }
  }

  double calculateSGPA(List<Map<String, dynamic>> semester) {
    double totalPoints = 0.0;
    int totalCredits = 0;
    for (var subject in semester) {
      totalPoints +=
          gradePoints[subject['grade']]! * (subject['credits'] as int);
      totalCredits += subject['credits'] as int;
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
  }

  double calculateCGPA() {
    double totalPoints = 0.0;
    int totalCredits = 0;
    for (var semester in semesters) {
      for (var subject in semester) {
        totalPoints +=
            gradePoints[subject['grade']]! * (subject['credits'] as int);
        totalCredits += subject['credits'] as int;
      }
    }
    return totalCredits > 0 ? (totalPoints / totalCredits) : 0.0;
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
                child: pw.Text('CGPA Transcript',
                    style: pw.TextStyle(
                        fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              ...semesters.asMap().entries.map((entry) {
                final index = entry.key;
                final semester = entry.value;
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Semester ${index + 1}',
                        style: pw.TextStyle(
                            fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                        'SGPA: ${calculateSGPA(semester).toStringAsFixed(2)}',
                        style: const pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 10),
                    pw.Table(
                      border: pw.TableBorder.all(),
                      children: [
                        pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Subject',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Credits',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(4),
                              child: pw.Text('Grade',
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...semester.map((subject) {
                          return pw.TableRow(
                            children: [
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(subject['name']),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(subject['credits'].toString()),
                              ),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(4),
                                child: pw.Text(subject['grade']),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                  ],
                );
              }),
              pw.SizedBox(height: 20),
              pw.Text('Overall CGPA: ${calculateCGPA().toStringAsFixed(2)}',
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
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error generating PDF: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CGPA Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: downloadTranscript,
            tooltip: 'Download Transcript',
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: widget.toggleTheme,
            tooltip: widget.isDarkMode
                ? 'Switch to Dark Mode'
                : 'Switch to Light Mode',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 8.0 : 24.0,
          vertical: 8.0,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: semesters.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Semester ${index + 1}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (semesters.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => removeSemester(index),
                                  tooltip: 'Remove Semester',
                                ),
                            ],
                          ),
                          const Divider(),
                          if (semesters[index].isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text(
                                'No subjects added yet',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ...semesters[index].asMap().entries.map((entry) {
                            final subjectIndex = entry.key;
                            final subject = entry.value;
                            return Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        initialValue: subject['name'],
                                        onChanged: (value) =>
                                            subject['name'] = value,
                                        decoration: const InputDecoration(
                                          labelText: 'Subject Name',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue:
                                            subject['credits'].toString(),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) {
                                          if (value.isNotEmpty) {
                                            subject['credits'] =
                                                int.tryParse(value) ?? 0;
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Credits',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: subject['grade'],
                                        items: gradePoints.keys.map((grade) {
                                          return DropdownMenuItem(
                                            value: grade,
                                            child: Text(grade),
                                          );
                                        }).toList(),
                                        onChanged: (value) => setState(
                                            () => subject['grade'] = value!),
                                        decoration: const InputDecoration(
                                          labelText: 'Grade',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                        isExpanded: true,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          removeSubject(index, subjectIndex),
                                      tooltip: 'Remove Subject',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],
                            );
                          }),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => addSubject(index),
                            child: const Text('Add Subject'),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SGPA:',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  calculateSGPA(semesters[index])
                                      .toStringAsFixed(2),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall CGPA:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      calculateCGPA().toStringAsFixed(2),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ElevatedButton.icon(
                onPressed: addSemester,
                icon: const Icon(Icons.add),
                label: const Text('Add Semester'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
