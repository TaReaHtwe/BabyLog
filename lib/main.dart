import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class EatTimerDialog extends StatefulWidget {
  final VoidCallback onDone;

  const EatTimerDialog({super.key, required this.onDone});

  @override
  State<EatTimerDialog> createState() => _EatTimerDialogState();
}

class _EatTimerDialogState extends State<EatTimerDialog> {
  late DateTime startTime;
  Timer? timer;
  Duration elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        elapsed = DateTime.now().difference(startTime);
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return AlertDialog(
      backgroundColor: const Color(0xFF16181D),
      title: const Row(
        children: [
          Icon(Icons.restaurant, color: Color(0xFFFFD54F)),
          SizedBox(width: 10),
          Text(
            'Breastfeeding Timer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Text(
        'Time elapsed: $minutes:${seconds.toString().padLeft(2, '0')}',
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onDone();
          },
          child: const Text(
            'DONE',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

void main() => runApp(const BabyTrackerApp());

class BabyTrackerApp extends StatefulWidget {
  const BabyTrackerApp({super.key});

  @override
  State<BabyTrackerApp> createState() => _BabyTrackerAppState();
}

class _BabyTrackerAppState extends State<BabyTrackerApp> {
  bool isDayTheme = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool('is_day_theme') ?? false;
    setState(() {
      isDayTheme = val;
    });
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isDayTheme = !isDayTheme;
    });
    await prefs.setBool('is_day_theme', isDayTheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDayTheme
          ? ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white)
          : ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF16181D),
            ),
      home: TrackerDashboard(isDayTheme: isDayTheme, toggleTheme: _toggleTheme),
    );
  }
}

class TrackerDashboard extends StatefulWidget {
  final bool isDayTheme;
  final VoidCallback toggleTheme;

  const TrackerDashboard({
    super.key,
    required this.isDayTheme,
    required this.toggleTheme,
  });

  @override
  State<TrackerDashboard> createState() => _TrackerDashboardState();
}

class _TrackerDashboardState extends State<TrackerDashboard> {
  List<Map<String, dynamic>> _logs = [];
  int feedCount = 0;
  int diaperCount = 0;
  String lastActivityText = "No activities yet";
  bool isEating = false;
  DateTime? eatStartTime;
  String babyName = "";
  DateTime? babyDob;

  @override
  void initState() {
    super.initState();
    _loadLogs(); // Load data as soon as the app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBabyName().then((_) => _loadBabyDob());
    });
  }

  Future<void> _loadBabyDob() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dobStr = prefs.getString('baby_dob');
    if (dobStr == null || dobStr.trim().isEmpty) {
      await _promptForDob();
    } else {
      try {
        final d = DateFormat('yyyy-MM-dd').parse(dobStr);
        setState(() {
          babyDob = d;
        });
      } catch (_) {
        // ignore parse errors and prompt again
        await _promptForDob();
      }
    }
  }

  Future<void> _promptForDob() async {
    // default to 3 months ago
    final DateTime initial = DateTime.now().subtract(const Duration(days: 90));
    final DateTime first = DateTime(2000);
    final DateTime last = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Select baby\'s date of birth',
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'baby_dob',
        DateFormat('yyyy-MM-dd').format(picked),
      );
      if (!mounted) return;
      setState(() {
        babyDob = picked;
      });
    }
  }

  String _ageString() {
    if (babyDob == null) return '';
    final now = DateTime.now();
    final totalDays = now.difference(babyDob!).inDays;
    if (totalDays < 30) {
      return '$totalDays Days';
    }
    if (totalDays < 365) {
      final months = totalDays ~/ 30;
      final days = totalDays % 30;
      return days == 0 ? '$months Months' : '$months Months $days Days';
    }
    final years = totalDays ~/ 365;
    final rem = totalDays % 365;
    final months = rem ~/ 30;
    return months == 0 ? '$years Years' : '$years Years $months Months';
  }

  Future<void> _loadBabyName() async {
    final prefs = await SharedPreferences.getInstance();
    final String? name = prefs.getString('baby_name');
    if (name == null || name.trim().isEmpty) {
      await _promptForBabyName();
    } else {
      setState(() {
        babyName = name;
      });
    }
  }

  Future<void> _promptForBabyName() async {
    final TextEditingController controller = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16181D),
          title: const Text(
            'What is your baby\'s name?',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name'),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // If user doesn't enter name allow them to skip by saving empty
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('baby_name', result);
      if (!mounted) return;
      setState(() {
        babyName = result;
      });
    }
  }

  Future<void> _editBabyName() async {
    final TextEditingController controller = TextEditingController(
      text: babyName,
    );
    String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16181D),
          title: const Text(
            'Edit baby\'s name',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name'),
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('baby_name', result);
      if (!mounted) return;
      setState(() {
        babyName = result;
      });
    }
  }

  Future<void> _showOnboardingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('seen_onboarding') ?? false;
    if (seen) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181D),
        title: const Text('Welcome', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tap the yellow EAT button to start a feeding timer.\n\nTap the name to edit it.\n\nLong-press timeline items to edit or delete them.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('seen_onboarding', true);
              navigator.pop();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  // --- PERSISTENCE LOGIC ---

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    // Convert the list to a JSON string to store it
    String encodedData = json.encode(_logs);
    await prefs.setString('baby_logs', encodedData);
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedData = prefs.getString('baby_logs');

    if (savedData != null) {
      setState(() {
        _logs = List<Map<String, dynamic>>.from(json.decode(savedData));
        _updateStats(); // Recalculate totals based on loaded data
      });
    }
  }

  void _updateStats() {
    if (_logs.isEmpty) {
      feedCount = 0;
      diaperCount = 0;
      lastActivityText = "No activities yet";
      return;
    }
    feedCount = _logs.where((l) => l['activity'] == "EAT").length;
    diaperCount = _logs
        .where((l) => l['activity'] == "WET" || l['activity'] == "POOP")
        .length;
    String activityText =
        "${_logs[0]['activity']}${_logs[0].containsKey('duration') ? "(${_logs[0]['duration']}mins)" : ""}";
    lastActivityText = "$activityText at ${_logs[0]['time']}";
  }

  // --- UI ACTIONS ---

  DateTime _getLogDateTime(Map<String, dynamic> log) {
    final time = DateFormat('h:mm a').parse(log['time']);
    final date = DateFormat('yyyy-MM-dd').parse(log['date']);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _addLog(
    String activity,
    Color color,
    IconData icon, {
    String? note,
    int? duration,
  }) {
    // If adding EAT and last activity is SLEEP, calculate sleep duration
    if (activity == "EAT" &&
        _logs.isNotEmpty &&
        _logs[0]['activity'] == "SLEEP") {
      final sleepStart = _getLogDateTime(_logs[0]);
      final now = DateTime.now();
      final sleepDuration = now.difference(sleepStart).inMinutes;
      _logs.insert(0, {
        'activity': 'SLEEP',
        'time': DateFormat('h:mm a').format(now),
        'date': DateFormat('yyyy-MM-dd').format(now),
        'colorValue': const Color(0xFF9575CD).toARGB32(),
        'iconCode': Icons.nightlight_round.codePoint,
        'duration': sleepDuration,
      });
    }
    setState(() {
      final now = DateTime.now();
      _logs.insert(0, {
        'activity': activity,
        'time': DateFormat('h:mm a').format(now),
        'date': DateFormat('yyyy-MM-dd').format(now),
        'colorValue': color.toARGB32(), // Store color as an integer for JSON
        'iconCode': icon.codePoint, // Store icon as a code for JSON
        if (note != null) 'note': note,
        if (duration != null) 'duration': duration,
      });
      _updateStats();
    });
    _saveLogs(); // Save after every addition
  }

  void _undoLastLog() {
    if (_logs.isEmpty) return;
    setState(() {
      _logs.removeAt(0);
      _updateStats();
    });
    _saveLogs(); // Save after undo
  }

  Future<void> _addNote() async {
    final TextEditingController controller = TextEditingController();
    final String? note = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Custom Note'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Enter your note'),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Add'),
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
            ),
          ],
        );
      },
    );
    if (note != null && note.isNotEmpty) {
      _addLog("NOTE", Colors.white, Icons.edit, note: note);
    }
  }

  void _handleEat() {
    if (!isEating) {
      setState(() {
        isEating = true;
        eatStartTime = DateTime.now();
      });
      showDialog(
        context: context,
        builder: (context) => EatTimerDialog(
          onDone: () {
            final duration = DateTime.now().difference(eatStartTime!);
            final minutes = duration.inMinutes;
            _addLog(
              "EAT",
              const Color(0xFFFFD54F),
              Icons.local_drink,
              duration: minutes,
            );
            setState(() {
              isEating = false;
              eatStartTime = null;
            });
          },
        ),
      );
    }
  }

  Future<void> _showCalendar() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selectedDate != null) {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final filteredLogs = _logs
          .where((log) => log['date'] == dateStr)
          .toList();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF16181D),
          title: Text(
            'Logs for ${DateFormat('MMMM d, yyyy').format(selectedDate)}',
            style: const TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: filteredLogs.isEmpty
                ? const Center(
                    child: Text(
                      'No logs for this date',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredLogs.length,
                    itemBuilder: (context, index) {
                      final log = filteredLogs[index];
                      return ListTile(
                        leading: log['activity'] == 'POOP'
                            ? const Text('💩', style: TextStyle(fontSize: 18))
                            : (log['activity'] == 'EAT'
                                  ? const Text(
                                      '🍼',
                                      style: TextStyle(fontSize: 18),
                                    )
                                  : Icon(
                                      IconData(
                                        log['iconCode'],
                                        fontFamily: 'MaterialIcons',
                                      ),
                                      color: Color(log['colorValue']),
                                    )),
                        title: Text(
                          log['activity'] == "NOTE"
                              ? (log['note'] ?? 'Note')
                              : (log['activity'] == "EAT" &&
                                        log.containsKey('duration')
                                    ? "EAT(${log['duration']}mins)"
                                    : (log['activity'] == "SLEEP" &&
                                              log.containsKey('duration')
                                          ? "SLEEP(${log['duration']}mins)"
                                          : log['activity'])),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          log['time'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  String _sleepLast12hText() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    int totalMinutes = 0;
    for (final log in _logs) {
      if (log['activity'] == 'SLEEP' && log.containsKey('duration')) {
        final date = DateFormat('yyyy-MM-dd').parse(log['date']);
        final time = DateFormat('h:mm a').parse(log['time']);
        final dt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (dt.isAfter(cutoff)) totalMinutes += (log['duration'] as int);
      }
    }
    if (totalMinutes == 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m';
  }

  // --- UI BUILDERS (Matches your screenshot) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              _buildHeader(),
              const SizedBox(height: 20),
              _buildLastActivityCard(),
              const SizedBox(height: 25),
              _buildSnapshot(),
              const SizedBox(height: 30),
              Text(
                "24-HOUR TIMELINE",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.isDayTheme ? Colors.black54 : Colors.blueGrey,
                ),
              ),
              Divider(
                color: widget.isDayTheme ? Colors.black26 : Colors.white10,
              ),
              Expanded(child: _buildTimeline()),
              _buildControlPanel(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // (Include the UI helper methods from the previous response here)
  // Note: Inside _buildTimeline, use IconData(log['iconCode'], fontFamily: 'MaterialIcons')
  // and Color(log['colorValue']) to restore the visual data.

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: _showCalendar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _editBabyName,
                child: Text(
                  babyName.isNotEmpty
                      ? "$babyName's Today Activities"
                      : "Today's Activities",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.isDayTheme ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showCalendar,
                child: Text(
                  DateFormat(
                    'EEEE, MMMM d',
                  ).format(DateTime.now()).toUpperCase(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.isDayTheme ? Colors.black54 : Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                widget.isDayTheme ? Icons.wb_sunny : Icons.nights_stay,
                color: widget.isDayTheme ? Colors.black54 : Colors.grey,
              ),
              onPressed: widget.toggleTheme,
              tooltip: 'Toggle day/night',
            ),
            IconButton(
              icon: Icon(
                Icons.undo,
                color: widget.isDayTheme ? Colors.black54 : Colors.grey,
              ),
              onPressed: _undoLastLog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLastActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 51, 71, 138),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "LAST ACTIVITY",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lastActivityText,
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 6),
              if (babyDob != null)
                Text(
                  _ageString(),
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
            ],
          ),
          const Icon(Icons.nightlight_round, size: 32, color: Colors.white24),
        ],
      ),
    );
  }

  Widget _buildSnapshot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _snapshotItem("$feedCount Feeds", Icons.restaurant),
        _snapshotItem("$diaperCount Diapers", Icons.water_drop),
        _snapshotItem(
          "${_sleepLast12hText()} Sleep",
          Icons.nightlight_round,
          onTap: _showSleepDetails,
        ),
      ],
    );
  }

  Widget _snapshotItem(String text, IconData icon, {VoidCallback? onTap}) {
    final child = Row(
      children: [
        Icon(icon, size: 14, color: Colors.blueGrey),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: child);
    }
    return child;
  }

  List<Map<String, dynamic>> _getSleepSegmentsLast12h() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    final List<Map<String, dynamic>> segments = [];
    for (final log in _logs) {
      if (log['activity'] == 'SLEEP') {
        final logDt = _getLogDateTime(log);
        int durationMinutes;
        if (log.containsKey('duration')) {
          durationMinutes = log['duration'] as int;
        } else {
          durationMinutes = DateTime.now().difference(logDt).inMinutes;
        }
        final endDt = logDt.add(Duration(minutes: durationMinutes));
        if (endDt.isAfter(cutoff) && logDt.isBefore(DateTime.now())) {
          segments.add({
            'time': log['time'],
            'date': log['date'],
            'duration': durationMinutes,
          });
        }
      }
    }
    return segments;
  }

  void _showSleepDetails() {
    final segments = _getSleepSegmentsLast12h();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF16181D),
        title: const Text(
          'Sleep — Last 12 hours',
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: segments.isEmpty
              ? const Center(
                  child: Text(
                    'No sleep recorded',
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  itemCount: segments.length,
                  itemBuilder: (context, index) {
                    final s = segments[index];
                    final mins = s['duration'] as int;
                    final h = mins ~/ 60;
                    final m = mins % 60;
                    final durText = h > 0 ? '${h}h ${m}m' : '${m}m';
                    return ListTile(
                      leading: const Icon(
                        Icons.nightlight_round,
                        color: Colors.white24,
                      ),
                      title: Text(
                        durText,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${s['time']} · ${s['date']}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return GestureDetector(
          onLongPress: () => _onTimelineLongPress(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    log['time'],
                    style: TextStyle(
                      color: widget.isDayTheme ? Colors.black54 : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  width: 15,
                  height: 1,
                  color: widget.isDayTheme ? Colors.black12 : Colors.white10,
                ),
                const SizedBox(width: 15),
                log['activity'] == 'POOP'
                    ? const Text('💩', style: TextStyle(fontSize: 18))
                    : (log['activity'] == 'EAT'
                          ? const Text('🍼', style: TextStyle(fontSize: 18))
                          : Icon(
                              IconData(
                                log['iconCode'],
                                fontFamily: 'MaterialIcons',
                              ),
                              size: 18,
                              color: Color(log['colorValue']),
                            )),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    log['activity'] == "NOTE"
                        ? (log['note'] ?? 'Note')
                        : (log['activity'] == "EAT" &&
                                  log.containsKey('duration')
                              ? "EAT(${log['duration']}mins)"
                              : (log['activity'] == "SLEEP" &&
                                        log.containsKey('duration')
                                    ? "SLEEP(${log['duration']}mins)"
                                    : log['activity'])),
                    style: TextStyle(
                      fontSize: 16,
                      color: widget.isDayTheme ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onTimelineLongPress(int index) {
    final log = _logs[index];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF16181D),
          title: Text(
            log['activity'] == 'NOTE'
                ? 'Note options'
                : '${log['activity']} options',
            style: const TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Choose an action for this entry',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            if (log['activity'] == 'NOTE')
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final TextEditingController controller =
                      TextEditingController(text: log['note'] ?? '');
                  final String? newNote = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF16181D),
                      title: const Text(
                        'Edit note',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: 'Note'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(null),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () =>
                              Navigator.of(context).pop(controller.text.trim()),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                  if (newNote != null) {
                    if (!mounted) return;
                    setState(() {
                      _logs[index]['note'] = newNote;
                      _updateStats();
                    });
                    _saveLogs();
                  }
                },
                child: const Text('Edit note'),
              ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF16181D),
                    title: const Text(
                      'Delete entry',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Are you sure you want to delete this entry?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _logs.removeAt(index);
                            _updateStats();
                          });
                          _saveLogs();
                          Navigator.of(context).pop();
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: _handleEat,
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      color: (isEating ? Colors.red : const Color(0xFFFFD54F))
                          .withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (isEating ? Colors.red : const Color(0xFFFFD54F))
                                  .withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('🍼', style: TextStyle(fontSize: 24)),
                        SizedBox(height: 4),
                        Text(
                          'EAT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _glowButton(
                  "SLEEP",
                  const Color(0xFF9575CD),
                  Icons.nightlight_round,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: GestureDetector(
                  onTap: () =>
                      _addLog("POOP", const Color(0xFFA1887F), Icons.waves),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFFA1887F).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFA1887F).withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('💩', style: TextStyle(fontSize: 24)),
                        SizedBox(height: 4),
                        Text(
                          'POOP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _glowButton(
                  "WET",
                  const Color(0xFF64B5F6),
                  Icons.baby_changing_station,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            shape: const StadiumBorder(),
          ),
          onPressed: _addNote,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text("NOTE"),
        ),
      ],
    );
  }

  Widget _glowButton(
    String label,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => _addLog(label, color, icon),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
