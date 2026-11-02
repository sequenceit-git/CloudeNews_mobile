import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class MeetingControlButton extends StatelessWidget {
  const MeetingControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.activeColor = AppColors.primary,
    this.hasBadge = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final Color activeColor;
  final bool hasBadge;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final bg = isActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.08);
    final fg = isActive ? activeColor : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: isActive ? activeColor.withValues(alpha: 0.5) : Colors.transparent),
                  ),
                  child: Icon(icon, color: fg, size: 20),
                ),
                if (hasBadge)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F141C),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
