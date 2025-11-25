import 'package:flutter/material.dart';
import 'package:terminal_library/xterm_library/xterm.dart';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DemoScreen(),
      theme: ThemeData.dark(),
    );
  }
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  final _terminal = TerminalLibraryFlutter(maxLines: 2000);
  final _controller = TerminalLibraryFlutterController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    _terminal.buffer.clear();
    // Fill with deterministic content for selection testing.
    final buffer = StringBuffer();
    buffer.writeln('Selection repro demo (no PTY; static content)');
    for (var i = 0; i < 400; i++) {
      buffer.writeln(
        '${i.toString().padLeft(4, "0")}: Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      );
    }
    _terminal.write(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal selection repro')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: TerminalLibraryFlutterViewWidget(
          _terminal,
          controller: _controller,
          scrollController: _scrollController,
          simulateScroll: false,
          alwaysShowCursor: true,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}
