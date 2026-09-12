import 'package:flutter/material.dart';

import '../../core/theme/vidhai_theme.dart';
import 'assistant_overlay.dart';
import 'assistant_session.dart';

/// One reusable assistant entry point used across all major VidhAI screens.
/// Tapping it opens the VidhAI Assistant overlay *on top of the current
/// screen* — it never navigates to AI Chat.
class VidhAIAssistantButton extends StatelessWidget {
  final String screen;
  final String? targetFarmId;
  final double size;
  final double iconSize;

  const VidhAIAssistantButton({
    super.key,
    required this.screen,
    this.targetFarmId,
    this.size = 40,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return GestureDetector(
      onTap: () {
        AssistantSession.instance.open(screen, targetFarmId: targetFarmId);
        showVidhAIAssistantOverlay(context);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: colors.borderColor),
          boxShadow: [
            BoxShadow(
              color: colors.brandDeep.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.auto_awesome_rounded,
          color: colors.brandDeep,
          size: iconSize,
        ),
      ),
    );
  }
}
