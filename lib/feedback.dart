import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class FeedbackService {
  static const String serviceId = 'service_rde8rx8';
  static const String templateId = 'template_y46xtxl';
  static const String userId = 'lxUF7C4z-EjiJhgZ8';

  /// Validates feedback fields
  static String? validateFeedback(
    String email,
    String subject,
    String message,
  ) {
    email = email.trim();
    subject = subject.trim();
    message = message.trim();

    if (email.isEmpty) {
      return 'Email address is required';
    }
    if (!_isValidEmail(email)) {
      return 'Please enter a valid email address';
    }
    if (subject.isEmpty) {
      return 'Subject is required';
    }
    if (message.isEmpty) {
      return 'Feedback content is required';
    }
    return null;
  }

  /// Simple email validation
  static bool _isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(email);
  }

  /// Checks if all feedback fields are filled
  static bool isFormComplete(String email, String subject, String message) {
    return email.trim().isNotEmpty &&
        subject.trim().isNotEmpty &&
        message.trim().isNotEmpty;
  }

  /// Sends feedback email via EmailJS
  static Future<void> sendFeedbackEmail(
    String userEmail,
    String subject,
    String message,
  ) async {
    final String email = userEmail.trim();
    final String subj = subject.trim();
    final String msg = message.trim();

    // Validate before sending
    final validationError = validateFeedback(email, subj, msg);
    if (validationError != null) {
      throw Exception(validationError);
    }

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
                'user_email': email,
                'subject': subj,
                'message': msg,
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
}

/// Helper function to easily trigger the modal from anywhere
void showFeedbackModal(BuildContext context) {
  showDialog(context: context, builder: (context) => const FeedbackDialog());
}

/// Stateful widget to manage the modal's internal state and memory
class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isSendingFeedback = false;

  @override
  void dispose() {
    _emailController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isFormComplete = FeedbackService.isFormComplete(
      _emailController.text,
      _subjectController.text,
      _contentController.text,
    );

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Send Feedback', style: TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              onChanged: (_) => setState(() {}),
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
              controller: _subjectController,
              onChanged: (_) => setState(() {}),
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
              controller: _contentController,
              onChanged: (_) => setState(() {}),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isFormComplete
                ? Colors.red
                : Colors.white.withOpacity(0.5),
          ),
          onPressed: _isSendingFeedback
              ? null
              : () async {
                  setState(() => _isSendingFeedback = true);
                  try {
                    await FeedbackService.sendFeedbackEmail(
                      _emailController.text,
                      _subjectController.text,
                      _contentController.text,
                    );
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feedback sent!')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    showDialog(
                      context: context,
                      builder: (alertContext) => AlertDialog(
                        backgroundColor: const Color(0xFF1A1A1A),
                        title: const Text(
                          'Error',
                          style: TextStyle(color: Colors.white),
                        ),
                        content: Text(
                          e.toString().replaceFirst('Exception: ', ''),
                          style: const TextStyle(color: Colors.white),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(alertContext),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _isSendingFeedback = false);
                    }
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
              : Text(
                  'Send',
                  style: TextStyle(
                    color: isFormComplete ? Colors.white : Colors.grey,
                  ),
                ),
        ),
      ],
    );
  }
}
