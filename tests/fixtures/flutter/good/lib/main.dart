import 'package:material_ui/material_ui.dart';

void main() => runApp(const DemoApp());

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Demo counter')),
        body: Center(child: Text('Count: $_count')),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _count++),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
