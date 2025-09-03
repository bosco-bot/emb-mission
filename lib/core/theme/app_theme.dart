import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Classe qui définit le thème de l'application EMB Mission
class AppTheme {
  // Couleurs principales de l'application
  static const Color primaryColor = Color(0xFFE53935); // Rouge EMB
  static const Color secondaryColor = Color(0xFF2196F3); // Bleu pour TV Live
  static const Color backgroundColor = Colors.white;
  static const Color cardColor = Color(0xFFF5F5F5);
  static const Color liveColor = Color(0xFFE57373);
  
  // Couleurs pour les catégories de témoignages
  static const Color healingColor = Color(0xFF64B5F6); // Bleu clair
  static const Color prayerColor = Color(0xFF9E9E9E); // Gris
  static const Color familyColor = Color(0xFFFFB74D); // Orange clair
  static const Color workColor = Color(0xFF4DB6AC); // Turquoise
  
  // Couleurs pour les différentes sections
  static const Color bibleColor = Color(0xFF90CAF9);
  static const Color testimonyColor = Color(0xFFCE93D8);
  static const Color communityColor = Color(0xFFFFCC80);
  
  // Schémas de couleurs pour le thème clair et sombre
  static final ColorScheme lightColorScheme = ColorScheme.light(
    primary: primaryColor,
    secondary: secondaryColor,
    surface: backgroundColor, // Remplacé background par surface
    surfaceTint: cardColor,
  );
  
  static final ColorScheme darkColorScheme = ColorScheme.dark(
    primary: primaryColor,
    secondary: secondaryColor,
    surface: const Color(0xFF121212), // Remplacé background par surface
    surfaceTint: const Color(0xFF1E1E1E),
  );
  
  // Thèmes pour les composants spécifiques
  static final appBarTheme = AppBarTheme(
    backgroundColor: backgroundColor,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.poppins(
      color: Colors.black,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  );
  
  static final darkAppBarTheme = AppBarTheme(
    backgroundColor: const Color(0xFF121212),
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.poppins(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  );
  
  static final CardThemeData cardTheme = CardThemeData(
    color: cardColor,
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  static final CardThemeData darkCardTheme = CardThemeData(
    color: const Color(0xFF1E1E1E),
    elevation: 2,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );
  
  static final elevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  );
  
  static final outlinedButtonTheme = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: primaryColor,
      side: BorderSide(color: primaryColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
    ),
  );
  
  static final bottomNavBarTheme = BottomNavigationBarThemeData(
    backgroundColor: backgroundColor,
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  );
  
  static final darkBottomNavBarTheme = BottomNavigationBarThemeData(
    backgroundColor: const Color(0xFF121212),
    selectedItemColor: primaryColor,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  );

  /// Thème clair de l'application
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: lightColorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: appBarTheme,
      cardTheme: cardTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      bottomNavigationBarTheme: bottomNavBarTheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(),
    );
  }

  /// Thème sombre de l'application (ébauche)
  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: darkColorScheme,
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: darkAppBarTheme,
      cardTheme: darkCardTheme,
      elevatedButtonTheme: elevatedButtonTheme,
      outlinedButtonTheme: outlinedButtonTheme,
      bottomNavigationBarTheme: darkBottomNavBarTheme,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
        ),
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    );
  }
}
