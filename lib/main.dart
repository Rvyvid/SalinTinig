import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'ocr_scanner.dart';
import 'language_switcher.dart';
import 'recording_overlay.dart';
//changes: imports for feedback function:
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
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
            Text(
              'SALINTINIG',
              style: GoogleFonts.anton(
                fontSize: 42,
                letterSpacing: 2,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              strokeWidth: 3,
              color: Colors.black,
            ),
            const SizedBox(height: 16),
            const Text(
              'Loading Translator...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
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

  //changes: variables for feedback function:
  final TextEditingController _feedbackEmailController =
      TextEditingController();
  final TextEditingController _feedbackSubjectController =
      TextEditingController();
  final TextEditingController _feedbackContentController =
      TextEditingController();
  bool _isSendingFeedback = false;
  //end of changes for feedback function

  String _sourceLang = "Tagalog";
  String _targetLang = "Cebuano";

  //changes: void homescreen function for feedback modal:
  void _showFeedbackModal() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text(
                'Send Feedback',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _feedbackEmailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Your Email Address',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _feedbackSubjectController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _feedbackContentController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Feedback Content',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _isSendingFeedback
                      ? null
                      : () async {
                          setStateModal(() => _isSendingFeedback = true);
                          try {
                            await _sendFeedbackEmail();
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Feedback sent!')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            Navigator.pop(context);
                          } finally {
                            setStateModal(() => _isSendingFeedback = false);
                          }
                        },
                  child: _isSendingFeedback
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // Clear controllers when modal closes
      _feedbackEmailController.clear();
      _feedbackSubjectController.clear();
      _feedbackContentController.clear();
    });
  }
  //end of changes for feedback function

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

  //changes: actual network call for feedback:
  Future<void> _sendFeedbackEmail() async {
    final String userEmail = _feedbackEmailController.text.trim();
    final String subject = _feedbackSubjectController.text.trim();
    final String message = _feedbackContentController.text.trim();

    if (userEmail.isEmpty || subject.isEmpty || message.isEmpty) return;

    // Replace these with your actual EmailJS credentials
    const String serviceId = 'service_rde8rx8';
    const String templateId = 'template_y46xtxl';
    const String userId = 'lxUF7C4z-EjiJhgZ8';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'service_id': serviceId,
              'template_id': templateId,
              'user_id': userId,
              'template_params': {
                'user_email': userEmail,
                'subject': subject,
                'message': message,
              },
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('EmailJS Response Status: ${response.statusCode}');
      debugPrint('EmailJS Response Body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to send email: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      rethrow;
    }
  }
  //end of changes

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
            onPressed: _showFeedbackModal,
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
