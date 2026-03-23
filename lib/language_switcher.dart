import 'package:flutter/material.dart';

class LanguageSwitcher extends StatelessWidget {
  final String sourceLang;
  final String targetLang;
  final VoidCallback onSwap;

  const LanguageSwitcher({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            sourceLang,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
          ),
          const SizedBox(width: 15),
          GestureDetector(
            onTap: onSwap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          Text(
            targetLang,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFB71C1C)),
          ),
        ],
      ),
    );
  }
}