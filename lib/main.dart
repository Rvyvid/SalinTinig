import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

// Your local imports
import 'ocr_scanner.dart';
import 'language_switcher.dart';
import 'recording_overlay.dart';
import 'feedback.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // Add this import
import 'api_config.dart';
import 'ble_detector.dart';
import 'package:audio_session/audio_session.dart';

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
//changes: added button for establishing BLE connection
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _handleConnectButtonPress() async {
    setState(() {
      _isConnecting = true;
    });

    bool success = await autoConnectToSalintinigDevice(context);

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ChatScreen()),
      );
    } else {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFD9D9D9),
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
            Text(
              'Real-time Filipino Translator',
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(
                fontSize: 18,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
            Text(
              '\nHow to Connect:'
              '\n1. Turn on your Salintinig Earphones'
              '\n2. Connect your device to "Salintinig Device" via Bluetooth'
              '\n3. Tap the button below to connect to the service!',
              style: GoogleFonts.openSans(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 24),
            _isConnecting
                ? const CircularProgressIndicator(color: Colors.white)
                : ElevatedButton.icon(
                    onPressed: _handleConnectButtonPress,
                    icon: const Icon(Icons.bluetooth, color: Colors.blue),
                    label: const Text("Connect Salintinig Earphones"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
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
  final AudioPlayer _ttsPlayer = AudioPlayer();

  String _sourceLang = "Tagalog";
  String _targetLang = "Cebuano";

  // -------------------------------------------------------
  // TTS — FIXED
  //
  // Root causes of the original stiff/broken audio:
  //  1. "fil-PH-Neural2-A"  → Neural2 does NOT exist for Filipino.
  //     Google silently falls back to Standard (the robotic one).
  //     Fix → use WaveNet, which is the best voice actually available.
  //
  //  2. "ceb-PH-Standard-A" → Google TTS has ZERO Cebuano voices.
  //     The language code itself is unsupported, so the request 400s.
  //     Fix → use fil-PH WaveNet (closest proxy) with a different
  //     voice variant + small pitch/rate offset to hint at Cebuano.
  //
  //  3. No _ttsPlayer.stop() before play → audio overlap on rapid taps.
  // -------------------------------------------------------
  Future<void> _speak(String text, String langName) async {
    if (text.isEmpty) return;
    try {
      final String lang = langName.trim().toLowerCase();
      final bool isCebuano = lang.contains("cebuano");

      // Google TTS has no Cebuano voice at all.
      // fil-PH WaveNet is the best available approximation.
      // WaveNet-A and WaveNet-C are distinct enough to feel different
      // between Tagalog and "Cebuano" outputs.
      const String languageCode = "fil-PH";
      final String voiceName = isCebuano
          ? "fil-PH-Wavenet-C"
          : "fil-PH-Wavenet-A";

      // Cebuano is spoken slightly faster with a higher pitch than Tagalog.
      // These values nudge the Filipino voice toward a Cebuano-like cadence.
      final double pitch = isCebuano ? 1.5 : 0.0;
      final double speakingRate = isCebuano ? 1.05 : 0.92;

      final response = await http.post(
        Uri.parse(
          "https://texttospeech.googleapis.com/v1/text:synthesize?key=${ApiConfig.ttsApiKey}",
        ),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "input": {"text": text},
          "voice": {
            "languageCode": languageCode,
            "name": voiceName,
            "ssmlGender": "FEMALE",
          },
          "audioConfig": {
            "audioEncoding": "MP3",
            "pitch": pitch,
            "speakingRate": speakingRate,
            // Adds warmth and reduces the "flat studio" TTS feel
            "effectsProfileId": ["headphone-class-device"],
          },
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final bytes = base64Decode(body['audioContent'] as String);
        // Stop previous playback before starting new one
        await _ttsPlayer.stop();
        await _ttsPlayer.play(BytesSource(bytes));
      } else {
        debugPrint("TTS API Error ${response.statusCode}: ${response.body}");
      }
    } catch (e) {
      debugPrint("TTS Execution Error: $e");
    }
  }

  // For BLE button controls
  StreamSubscription<int>? _buttonSub;

  //changes for BLE application
  @override
  void initState() {
    super.initState();
    _requestAudioFocus();
    startBleListener(
      context,
      onExitApp: () {
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (Route<dynamic> route) => false,
          );
        }
      },
    );

    // Listen to hardware button presses
    _buttonSub = salintinigButtonStream.stream.listen((eventCode) {
      if (!mounted) return;
      setState(() {
        if (eventCode == 1) {
          _sourceLang = "Tagalog";
          _targetLang = "Cebuano";
        } else if (eventCode == 2) {
          _sourceLang = "Cebuano";
          _targetLang = "Tagalog";
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to $_sourceLang ➔ $_targetLang'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.black87,
        ),
      );
    });
  }

  // @override
  // void dispose() {
  //   _buttonSub?.cancel(); // cancel BLE button subscription
  //   stopBleListener();
  //   _controller.dispose();
  //   super.dispose();
  // }
  //end changes for BLE application

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

  Future<void> _requestAudioFocus() async {
    try {
      final session = await AudioSession.instance;
      // Configuring as "speech" strictly pauses background media apps
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);
      debugPrint("Audio session activated. Background media paused.");
    } catch (e) {
      debugPrint("Failed to set audio session: $e");
    }
  }

  Future<void> _onMicPressed() async {
    final status = await Permission.microphone.request();
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
              "from": _sourceLang,
              "time": TimeOfDay.now().format(context),
            });
          });
        },
      );
    }
  }

  Future<void> _onCameraPressed() async {
    final status = await Permission.camera.request();
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
  void dispose() {
    //changes: joined dispose
    _buttonSub?.cancel(); // cancel BLE button subscription
    stopBleListener();
    _controller.dispose();
    _ttsPlayer.dispose();
    _controller.dispose();
    super.dispose();
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
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Start translating...'))
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
                  child: kIsWeb
                      ? Image.network(
                          msg["imagePath"],
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                              ),
                        )
                      : Image.file(File(msg["imagePath"])),
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
                Expanded(
                  child: isAudio
                      ? _buildAudioPlayerUI(msg["audioPath"] as String?)
                      : Text(
                          msg["text"] ?? "",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                ),
                if (!isAudio)
                  IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.redAccent),
                    onPressed: () =>
                        _speak(msg["text"] as String, msg["to"] as String),
                  ),
              ],
            ),
            Text(
              "${msg["from"]} ➔ ${msg["to"]} • ${msg["time"]}",
              style: const TextStyle(color: Colors.redAccent, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayerUI(String? path) {
    if (path == null) {
      return const Text("Audio Error", style: TextStyle(color: Colors.white));
    }

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
                  // onPressed: () async {
                  //   if (isPlaying) {
                  //     await audioPlayer.pause();
                  //   } else {
                  //     await audioPlayer.play(DeviceFileSource(path));
                  //   }
                  // },
                  onPressed: () async {
                    if (isPlaying) {
                      await audioPlayer.pause();
                    } else {
                      if (kIsWeb ||
                          path.startsWith('http') ||
                          path.startsWith('blob:')) {
                        // Use UrlSource for Web Blobs or Network paths
                        await audioPlayer.play(UrlSource(path));
                      } else {
                        // Use DeviceFileSource for local mobile files
                        await audioPlayer.play(DeviceFileSource(path));
                      }
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
