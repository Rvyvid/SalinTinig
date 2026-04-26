import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:io';

class OCRScannerScreen extends StatefulWidget {
  const OCRScannerScreen({super.key});

  @override
  State<OCRScannerScreen> createState() => _OCRScannerScreenState();
}

class _OCRScannerScreenState extends State<OCRScannerScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      // Only initialize camera on mobile platforms
      _setupCamera();
    }
  }

  Future<void> _setupCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras found");
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
      );

      await _controller!.initialize();

      if (!mounted) return;
      setState(() => _isInitialized = true);
      debugPrint(
        "Camera initialized successfully: ${_controller!.description.name}",
      );
    } catch (e) {
      debugPrint("Camera Setup Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Camera Error: $e")));
      }
    }
  }

  /// Web: Pick image from file picker / camera
  Future<void> _pickImageForWeb() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );

      if (image != null && mounted) {
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  /// Mobile: Take photo using camera
  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint("Error capturing photo: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Web version: Simple file picker UI
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'BACK',
                      style: GoogleFonts.anton(
                        fontSize: 28,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 60,
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Capture or Upload Image',
                              style: GoogleFonts.anton(
                                fontSize: 18,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 30),
                            ElevatedButton.icon(
                              onPressed: _pickImageForWeb,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB71C1C),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 30,
                                  vertical: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    // Mobile version: Live camera UI
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.black,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'BACK',
                    style: GoogleFonts.anton(fontSize: 28, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            // Camera Viewport
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isInitialized)
                        CameraPreview(_controller!)
                      else
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      const ScannerOverlay(),
                      Positioned(
                        bottom: 30,
                        child: GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child: Icon(
                                Icons.camera_alt,
                                color: Color(0xFFB71C1C),
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Custom widget to draw the brackets from your image
class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 400,
      child: Stack(
        children: [
          _buildCorner(top: true, left: true),
          _buildCorner(top: true, left: false),
          _buildCorner(top: false, left: true),
          _buildCorner(top: false, left: false),
        ],
      ),
    );
  }

  Widget _buildCorner({required bool top, required bool left}) {
    return Positioned(
      top: top ? 0 : null,
      bottom: !top ? 0 : null,
      left: left ? 0 : null,
      right: !left ? 0 : null,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            bottom: !top
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            left: left
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
            right: !left
                ? const BorderSide(color: Colors.white, width: 4)
                : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(20) : Radius.zero,
            topRight: top && !left ? const Radius.circular(20) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(20) : Radius.zero,
            bottomRight: !top && !left
                ? const Radius.circular(20)
                : Radius.zero,
          ),
        ),
      ),
    );
  }
}
