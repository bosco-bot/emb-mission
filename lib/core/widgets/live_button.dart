import 'package:flutter/material.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Widget pour les boutons de diffusion en direct (Radio Live, TV Live)
class LiveButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLarge;

  const LiveButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLarge = true,
  });

  /// Bouton Radio Live
  factory LiveButton.radio({
    Key? key,
    required VoidCallback onTap,
    bool isLarge = true,
  }) {
    return LiveButton(
      key: key,
      title: 'Radio Live',
      icon: Icons.radio,
      color: AppTheme.primaryColor,
      onTap: onTap,
      isLarge: isLarge,
    );
  }

  /// Bouton TV Live
  factory LiveButton.tv({
    Key? key,
    required VoidCallback onTap,
    bool isLarge = true,
  }) {
    return LiveButton(
      key: key,
      title: 'TV Live',
      icon: Icons.tv,
      color: AppTheme.secondaryColor,
      onTap: onTap,
      isLarge: isLarge,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isLarge ? double.infinity : 120,
        height: isLarge ? 56 : 48,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: isLarge ? 24 : 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: isLarge ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
