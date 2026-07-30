import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Entry point ng application.
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

/// Nagma-manage ng app theme gamit ang Provider.
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  /// Ibinabalik ang kasalukuyang theme mode.
  bool get isDarkMode => _isDarkMode;

  /// Pinapalitan ang theme mula light papuntang dark at vice versa.
  void toggleTheme(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}

/// Main widget ng application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Ephemeral vs App State',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode:
              themeProvider.isDarkMode
                  ? ThemeMode.dark
                  : ThemeMode.light,
          home: const CounterScreen(),
        );
      },
    );
  }
}

/// Unang screen na nagpapakita ng Ephemeral State gamit ang setState().
class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  int counter = 0;

  /// Dinadagdagan ang value ng counter.
  void incrementCounter() {
    setState(() {
      counter++;
    });
  }

  /// Binabawasan ang value ng counter.
  void decrementCounter() {
    setState(() {
      counter--;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter Screen'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Counter Value',
              style: TextStyle(
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 15),

            Text(
              '$counter',
              style: const TextStyle(
                fontSize: 45,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: decrementCounter,
                  child: const Text('-'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: incrementCounter,
                  child: const Text('+'),
                ),
              ],
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ThemeScreen(),
                  ),
                );
              },
              child: const Text('Go to Theme Settings'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pangalawang screen na nagpapakita ng App State gamit ang Provider.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        centerTitle: true,
      ),
      body: Center(
        child: SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text(
            'Toggle the application theme',
          ),
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            themeProvider.toggleTheme(value);
          },
        ),
      ),
    );
  }
}