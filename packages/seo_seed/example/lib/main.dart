import 'package:flutter/material.dart';
import 'package:seo_seed/runtime.dart';

void main() {
  SeoRuntime.takeover();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'seo_seed demo',
      theme: ThemeData(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sortd')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: const Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Simple pricing',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Sortd is free for personal groups. '
                  'Upgrade for receipt scanning and multi-currency.',
                ),
                SizedBox(height: 32),
                Text(
                  'Splitting rent fairly',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Splitting rent evenly is rarely fair when rooms differ '
                  'in size.',
                ),
                SizedBox(height: 8),
                Text(
                  'Sortd lets you split by shares, so a larger room can '
                  'carry more.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
