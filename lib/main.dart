import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ocr_scanner.dart';
import 'language_switcher.dart';

void main() {
  runApp(const SalintinigApp());
}

class SalintinigApp extends StatelessWidget {
  const SalintinigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Salintinig',
      theme: ThemeData(primarySwatch: Colors.red),
      home: const HomeScreen(),
    );
  }
}

// =================== HOME SCREEN (Splash) ===================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('SALINTINIG', 
              style: GoogleFonts.anton(fontSize: 42, letterSpacing: 2, color: Colors.black)),
            const SizedBox(height: 24),
            const CircularProgressIndicator(strokeWidth: 3, color: Colors.black),
            const SizedBox(height: 16),
            const Text('Loading Translator...', 
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ======================= CHAT SCREEN =======================
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  String _sourceLang = "Tagalog";
  String _targetLang = "Cebuano";

  void _swapLanguages() {
    setState(() {
      final temp = _sourceLang;
      _sourceLang = _targetLang;
      _targetLang = temp;
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, {
        "originalText": text, // The text exactly as typed
        "text": text,         // Placeholder for the translated result
        "imagePath": null,
        "from": _sourceLang,
        "to": _targetLang,
        "time": TimeOfDay.now().format(context),
      });
    });
    _controller.clear();
  }

  Future<void> _onMicPressed() async {
    final status = await Permission.microphone.request();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(status.isGranted 
          ? 'Listening in $_sourceLang...' 
          : 'Microphone permission denied')),
    );
  }

  Future<void> _onCameraPressed() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isGranted) {
      final String? path = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const OCRScannerScreen()),
      );

      if (path != null) {
        setState(() {
          _messages.insert(0, {
            "imagePath": path,
            "originalText": "Image Captured",
            "text": "Scanning $_sourceLang text...",
            "from": _sourceLang,
            "to": _targetLang,
            "time": TimeOfDay.now().format(context),
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.translate, color: Colors.black),
            const SizedBox(width: 12),
            Text('SALINTINIG', 
              style: GoogleFonts.anton(fontSize: 22, color: Colors.black)),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.history, color: Colors.black)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('Start translating $_sourceLang to $_targetLang', 
                    style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      return _buildChatBubble(msg);
                    },
                  ),
          ),

          LanguageSwitcher(
            sourceLang: _sourceLang,
            targetLang: _targetLang,
            onSwap: _swapLanguages,
          ),

          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(Map<String, dynamic> msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display Image if it exists
            if (msg["imagePath"] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(msg["imagePath"])),
                ),
              ),
            
            // NEW: Show the original typed text (italicized)
            if (msg["originalText"] != null)
              Text(
                "Original: ${msg["originalText"]}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            
            const SizedBox(height: 4),

            // Display the main translated text
            Text(msg["text"] ?? "", 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 17, 
                fontWeight: FontWeight.w500
              )),
            
            const SizedBox(height: 6),

            // Language labels and timestamp
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${msg["from"]} ➔ ${msg["to"]}", 
                  style: TextStyle(
                    color: Colors.redAccent.shade100, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold
                  )),
                const SizedBox(width: 8),
                Text(msg["time"], 
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5), 
                    fontSize: 10
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          hintText: "Type in $_sourceLang...",
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded, color: Color(0xFFB71C1C)),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.mic_none_rounded, color: Colors.white),
              onPressed: _onMicPressed,
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              onPressed: _onCameraPressed,
            ),
          ],
        ),
      ),
    );
  }
}