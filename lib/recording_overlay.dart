import 'dart:async';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart'; // New Import

class RecordingOverlay {
  static void show(BuildContext context, {required Function(String path, String transcript) onStop}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (context) => _RecordingSheet(onStop: onStop),
    );
  }
}

class _RecordingSheet extends StatefulWidget {
  final Function(String path, String transcript) onStop;
  const _RecordingSheet({required this.onStop});

  @override
  State<_RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends State<_RecordingSheet> {
  late AudioRecorder _audioRecorder;
  final SpeechToText _speechToText = SpeechToText(); // STT Instance
  
  Timer? _timer;
  int _seconds = 0;
  String _wordsSpoken = ""; // To store transcription
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _initSpeech();
  }

  /// Initialize Speech Recognition
  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    _startRecording();
  }

  void _startRecording() async {
    try {
      // Check for both microphone and speech permissions
      if (await _audioRecorder.hasPermission() && _speechEnabled) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // 1. Start Audio File Recording
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: path
        );

        // 2. Start Speech to Text
        await _speechToText.listen(
          onResult: (result) {
            setState(() {
              _wordsSpoken = result.recognizedWords;
            });
          },
        );
        
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) setState(() => _seconds++);
        });
      }
    } catch (e) {
      debugPrint("Recording Error: $e");
    }
  }

  void _stopAndSend() async {
    final path = await _audioRecorder.stop();
    await _speechToText.stop(); // Stop STT
    
    _timer?.cancel();
    if (path != null) {
      widget.onStop(path, _wordsSpoken); // Return both path and text
    }
    if (mounted) Navigator.pop(context);
  }

  void _reset() async {
    await _audioRecorder.stop();
    await _speechToText.stop();
    _timer?.cancel();
    setState(() {
      _seconds = 0;
      _wordsSpoken = "";
    });
    _startRecording();
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString();
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$mins:$secs";
  }

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    _speechToText.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350, // Increased height for text preview
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          
          // Live Transcription Preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _wordsSpoken.isEmpty ? "Listening..." : _wordsSpoken,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic),
            ),
          ),
          
          const Spacer(),
          const Icon(Icons.mic, color: Colors.redAccent, size: 48),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [ 
              const Icon(Icons.graphic_eq, color: Colors.redAccent, size: 28),
              const SizedBox(width: 12),
              Text(_formatTime(_seconds), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300)),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 40, 30),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.refresh, color: Colors.white, size: 32), onPressed: _reset),
                GestureDetector(
                  onTap: _stopAndSend,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Color(0xFFB71C1C), size: 30),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}