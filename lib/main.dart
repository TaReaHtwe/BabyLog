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
  late Timer timer;
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
    timer.cancel();
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
          Text('Breastfeeding Timer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
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
          child: const Text('DONE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

void main() => runApp(const BabyTrackerApp());

class BabyTrackerApp extends StatelessWidget {
  const BabyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF16181D),
      ),
      home: const TrackerDashboard(),
    );
  }
}

class TrackerDashboard extends StatefulWidget {
  const TrackerDashboard({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadLogs(); // Load data as soon as the app opens
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
    diaperCount = _logs.where((l) => l['activity'] == "WET" || l['activity'] == "POOP").length;
    String activityText = "${_logs[0]['activity']}${_logs[0].containsKey('duration') ? "(${_logs[0]['duration']}mins)" : ""}";
    lastActivityText = "$activityText at ${_logs[0]['time']}";
  }

  // --- UI ACTIONS ---

  DateTime _getLogDateTime(Map<String, dynamic> log) {
    final time = DateFormat('h:mm a').parse(log['time']);
    final date = DateFormat('yyyy-MM-dd').parse(log['date']);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _addLog(String activity, Color color, IconData icon, {String? note, int? duration}) {
    // If adding EAT and last activity is SLEEP, calculate sleep duration
    if (activity == "EAT" && _logs.isNotEmpty && _logs[0]['activity'] == "SLEEP") {
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
              onPressed: () => Navigator.of(context).pop(controller.text.trim()),
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
            _addLog("EAT", const Color(0xFFFFD54F), Icons.baby_changing_station, duration: minutes);
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
      final filteredLogs = _logs.where((log) => log['date'] == dateStr).toList();
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
                        leading: Icon(
                          IconData(log['iconCode'], fontFamily: 'MaterialIcons'),
                          color: Color(log['colorValue']),
                        ),
                        title: Text(
                          log['activity'] == "NOTE"
                              ? (log['note'] ?? 'Note')
                              : (log['activity'] == "EAT" && log.containsKey('duration')
                                  ? "EAT(${log['duration']}mins)"
                                  : (log['activity'] == "SLEEP" && log.containsKey('duration')
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
              const Text("24-HOUR TIMELINE", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const Divider(color: Colors.white10),
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
          child: Text(DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
        ),
        IconButton(icon: const Icon(Icons.undo, color: Colors.grey), onPressed: _undoLastLog),
      ],
    );
  }

  Widget _buildLastActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF242835), borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("LAST ACTIVITY", style: TextStyle(color: Colors.blueGrey, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(lastActivityText, style: const TextStyle(fontSize: 18, color: Colors.white)),
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
        _snapshotItem("12h Sleep", Icons.access_time),
      ],
    );
  }

  Widget _snapshotItem(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 14, color: Colors.blueGrey),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(color: Colors.blueGrey, fontSize: 13))
    ]);
  }

  Widget _buildTimeline() {
    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              SizedBox(width: 70, child: Text(log['time'], style: const TextStyle(color: Colors.grey, fontSize: 13))),
              Container(width: 15, height: 1, color: Colors.white10),
              const SizedBox(width: 15),
              Icon(IconData(log['iconCode'], fontFamily: 'MaterialIcons'), size: 18, color: Color(log['colorValue'])),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  log['activity'] == "NOTE" ? (log['note'] ?? 'Note') : 
                  (log['activity'] == "EAT" && log.containsKey('duration') ? "EAT(${log['duration']}mins)" : 
                  (log['activity'] == "SLEEP" && log.containsKey('duration') ? "SLEEP(${log['duration']}mins)" : log['activity'])),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlPanel() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _glowButton("EAT", isEating ? Colors.red : const Color(0xFFFFD54F), Icons.baby_changing_station, onTap: _handleEat),
            _glowButton("SLEEP", const Color(0xFF9575CD), Icons.nightlight_round),
            _glowButton("POOP", const Color(0xFFA1887F), Icons.waves),
            _glowButton("WET", const Color(0xFF64B5F6), Icons.water_drop),
          ],
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, shape: const StadiumBorder()),
          onPressed: _addNote,
          icon: const Icon(Icons.edit, size: 18),
          label: const Text("NOTE"),
        ),
      ],
    );
  }

  Widget _glowButton(String label, Color color, IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () => _addLog(label, color, icon),
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}