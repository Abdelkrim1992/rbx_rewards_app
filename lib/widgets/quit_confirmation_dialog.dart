import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'interactive_button.dart';

Future<bool> showQuitConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Quit',
}) async {
  final shouldQuit = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        title,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: const Color(0xFF131326),
        ),
      ),
      content: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: const Color(0xFF4A4B60),
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: InteractiveButton(
                text: 'Cancel',
                onTap: () => Navigator.pop(ctx, false),
                backgroundColor: const Color(0xFFF1F1FB),
                textColor: const Color(0xFF868A9F),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InteractiveButton(
                text: confirmText,
                onTap: () => Navigator.pop(ctx, true),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  return shouldQuit == true;
}
