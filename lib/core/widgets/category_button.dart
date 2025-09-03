import 'package:flutter/material.dart';
import 'package:emb_mission/core/models/testimony.dart';
import 'package:emb_mission/core/theme/app_theme.dart';

/// Widget pour les boutons de catégorie (Bible, Prières, Témoignages, etc.)
class CategoryButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isSelected;

  const CategoryButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isSelected = false,
  });
  
  /// Constructeur alternatif qui utilise label au lieu de title
  factory CategoryButton.withLabel({
    Key? key,
    required String label,
    IconData? icon,
    required Color color,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return CategoryButton(
      key: key,
      title: label,
      icon: icon ?? Icons.label,
      color: color,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  /// Bouton pour la Bible
  factory CategoryButton.bible({
    Key? key,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return CategoryButton(
      key: key,
      title: 'Bible',
      icon: Icons.menu_book,
      color: AppTheme.bibleColor,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  /// Bouton pour les Prières
  factory CategoryButton.prayer({
    Key? key,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return CategoryButton(
      key: key,
      title: 'Prières',
      icon: Icons.volunteer_activism,
      color: AppTheme.prayerColor,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  /// Bouton pour les Témoignages
  factory CategoryButton.testimony({
    Key? key,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return CategoryButton(
      key: key,
      title: 'Témoignages',
      icon: Icons.favorite,
      color: AppTheme.testimonyColor,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  /// Bouton pour la Communauté
  factory CategoryButton.community({
    Key? key,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return CategoryButton(
      key: key,
      title: 'Communauté',
      icon: Icons.people,
      color: AppTheme.communityColor,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  /// Bouton pour les catégories de témoignages
  factory CategoryButton.testimonyCategory({
    Key? key,
    required TestimonyCategory category,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    IconData icon;
    Color color;
    
    switch (category) {
      case TestimonyCategory.healing:
        icon = Icons.favorite;
        color = AppTheme.healingColor;
        break;
      case TestimonyCategory.prayer:
        icon = Icons.volunteer_activism;
        color = AppTheme.prayerColor;
        break;
      case TestimonyCategory.family:
        icon = Icons.family_restroom;
        color = AppTheme.familyColor;
        break;
      case TestimonyCategory.work:
        icon = Icons.work;
        color = AppTheme.workColor;
        break;
    }
    
    return CategoryButton(
      key: key,
      title: category.displayName,
      icon: icon,
      color: color,
      onTap: onTap,
      isSelected: isSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.2) 
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: isSelected 
              ? Border.all(color: color, width: 2)
              : null,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? color : Colors.grey[800],
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
