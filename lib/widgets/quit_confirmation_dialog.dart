import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F1FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF868A9F),
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF5252), Color(0xFFFF1744)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF1744).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    confirmText,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
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
