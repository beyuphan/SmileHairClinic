import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Paletimizi tanımlayalım
const Color _primaryColor = Color(0xFF006A7A); // Koyu Teal (Güven)
const Color _accentColor = Color(0xFFFF7F50); // Koral (Tutku)
const Color _lightBgColor = Color(0xFFFAFAFA); // Kırık Beyaz (Sadelik)
const Color _darkBgColor = Color(0xFF121212);  // Neredeyse Siyah (Premium)
const Color _darkSurfaceColor = Color(0xFF1E1E1E); // Koyu Kart Rengi

class AppThemes {
  // "Sade, Premium, Tutkulu" AÇIK TEMA
  static final ThemeData lightTheme = ThemeData.from(
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: _primaryColor,
      onPrimary: Colors.white,
      secondary: _accentColor, // "Tutku" rengimiz
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      background: _lightBgColor,
      onBackground: Colors.black,
      surface: Colors.white, // Kartların rengi
      onSurface: Colors.black,
    ),
    // Yazı Tipi: "Inter" (Premium ve Temiz)
    textTheme: GoogleFonts.interTextTheme(),
  ).copyWith(
    // AppBar'ı (üst bar) özelleştir
    appBarTheme: AppBarTheme(
      elevation: 0.5,
      backgroundColor: Colors.white, // Saf beyaz
      foregroundColor: Colors.black, // Başlık ve ikon renkleri
      titleTextStyle: GoogleFonts.inter(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    // "Tutkulu" Buton Teması
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor, // Arkaplan Koral
        foregroundColor: Colors.white, // Yazı Beyaz
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );

  // "Sade, Premium, Tutkulu" KOYU TEMA
  static final ThemeData darkTheme = ThemeData.from(
    colorScheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: _primaryColor, // Ana renk (Teal)
      onPrimary: Colors.white,
      secondary: _accentColor, // "Tutku" rengimiz
      onSecondary: Colors.white,
      error: Colors.redAccent,
      onError: Colors.white,
      background: _darkBgColor,
      onBackground: Colors.white,
      surface: _darkSurfaceColor, // Kartların rengi
      onSurface: Colors.white,
    ),
    textTheme: GoogleFonts.interTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
  ).copyWith(
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: _darkSurfaceColor, // Koyu kart rengi
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _accentColor, // Arkaplan Koral
        foregroundColor: Colors.white,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );
}