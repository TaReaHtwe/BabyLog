import 'package:flutter/material.dart';

//adding commit on new branch
// This is a simple Flutter app that tracks baby activities and vaccinations.
void main() => runApp(const BabyTrackerApp());

class BabyTrackerApp extends StatefulWidget {
  const BabyTrackerApp({super.key});

  @override
  State<BabyTrackerApp> createState() => _BabyTrackerAppState();
}

class _BabyTrackerAppState extends State<BabyTrackerApp> {
  bool isDayTheme = false;

  void _toggleTheme() => setState(() => isDayTheme = !isDayTheme);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: isDayTheme ? ThemeData.light() : ThemeData.dark(),
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
  int _selectedIndex = 0;

  void _onTap(int i) => setState(() => _selectedIndex = i);

  Widget _homeScreen() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "BabyLog",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.isDayTheme ? Icons.wb_sunny : Icons.nights_stay,
                      ),
                      onPressed: widget.toggleTheme,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              "24-HOUR TIMELINE",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) => ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text('Activity #${index + 1}'),
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit),
              label: const Text('NOTE'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vaccineScreen() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.medical_services, size: 56, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Vaccine',
                style: TextStyle(fontSize: 22, color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                'Vaccination records and reminders will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0 ? _homeScreen() : _vaccineScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.medical_services),
            label: 'Vaccine',
          ),
        ],
      ),
    );
  }
}
