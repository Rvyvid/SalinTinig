import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Add this import
import 'ocr_scanner.dart';
import 'language_switcher.dart';
import 'recording_overlay.dart';
import 'feedback.dart';
import 'ble_detector.dart'; // New Import for BLE Detection

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

// class _HomeScreenState extends State<HomeScreen> {
//   @override
//   void initState() {
//     super.initState();
//     _connectBleAndNavigate();
//   }

//   Future<void> _connectBleAndNavigate() async {
//     // Attempt BLE connection
//     bool connected = await autoConnectToSalintinigDevice(context);

//     if (!mounted) return;

//     // If connection successful or after timeout, navigate to ChatScreen
//     Navigator.of(
//       context,
//     ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFD9D9D9),
//       body: Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               'SALINTINIG',
//               style: GoogleFonts.anton(
//                 fontSize: 42,
//                 letterSpacing: 2,
//                 color: Colors.black,
//               ),
//             ),
//             const SizedBox(height: 24),
//             const CircularProgressIndicator(
//               strokeWidth: 3,
//               color: Colors.black,
//             ),
//             const SizedBox(height: 16),
//             const Text(
//               'Loading Translator...',
//               style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // ❌ REMOVE auto-connect from here.
    // Web browsers will block this because there was no user click.
  }

  // ✅ Create a function to be called by a button press
  Future<void> _handleConnectButtonPress() async {
    setState(() {
      _isConnecting = true;
    });

    // This is now legally a "user gesture" to the browser
    bool success = await autoConnectToSalintinigDevice(context);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    } else {
      setState(() {
        _isConnecting = false;
      });
      // A snackbar is already handled in your ble_detector.dart for failures,
      // but we reset the loading state here.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9), // Matching your theme
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'SALINTINIG',
              style: GoogleFonts.anton(
                fontSize: 42,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            // Show a loading spinner if connecting, otherwise show the button
            _isConnecting
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton.icon(
                    onPressed:
                        _handleConnectButtonPress, // The critical user gesture
                    icon: const Icon(Icons.bluetooth),
                    label: const Text("Connect Salintinig Earphones"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
        "isAudio": false,
        "originalText": text,
        "text": text,
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

    if (status.isGranted) {
      RecordingOverlay.show(
        context,
        onStop: (filePath, transcript) {
          setState(() {
            _messages.insert(0, {
              "isAudio": true,
              "audioPath": filePath,
              "originalText": transcript.isNotEmpty
                  ? transcript
                  : "Voice Recording",
              "text": "Voice Message",
              "to": _targetLang,
              "time": TimeOfDay.now().format(context),
            });
          });
        },
      );
    }
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
            "isAudio": false,
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
            Text(
              'SALINTINIG',
              style: GoogleFonts.anton(fontSize: 22, color: Colors.black),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.feedback_outlined, color: Colors.black),
            onPressed: () => showFeedbackModal(context),
            tooltip: 'Send Feedback',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start translating...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    reverse: true,
                    itemBuilder: (context, index) =>
                        _buildChatBubble(_messages[index]),
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
    final bool isAudio = msg["isAudio"] ?? false;

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
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg["imagePath"] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(msg["imagePath"])),
                ),
              ),
            if (msg["originalText"] != null)
              Text(
                "Original: ${msg["originalText"]}",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 4),

            // CONTENT AREA
            if (isAudio)
              _buildAudioPlayerUI(msg["audioPath"])
            else
              Text(
                msg["text"] ?? "",
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),

            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${msg["from"]} ➔ ${msg["to"]}",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  msg["time"],
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayerUI(String? path) {
    if (path == null) {
      return const Text(
        "Audio file missing",
        style: TextStyle(color: Colors.white),
      );
    }

    // We create a single player instance for this bubble
    final AudioPlayer audioPlayer = AudioPlayer();

    return StatefulBuilder(
      builder: (context, setBubbleState) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<PlayerState>(
              stream: audioPlayer.onPlayerStateChanged,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final bool isPlaying = playerState == PlayerState.playing;

                return IconButton(
                  icon: Icon(
                    isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 38,
                  ),
                  onPressed: () async {
                    if (isPlaying) {
                      await audioPlayer.pause();
                    } else {
                      await audioPlayer.play(DeviceFileSource(path));
                    }
                  },
                );
              },
            ),
            const Text(
              "Voice Message",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: "Type in $_sourceLang...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
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
