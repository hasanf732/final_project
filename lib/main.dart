import 'package:final_project/Pages/splash_screen.dart';
import 'package:final_project/services/notification_service.dart';
import 'package:final_project/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // It's no longer necessary to initialize the Google Maps renderer manually.
  // The plugin handles this automatically.

  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  await _requestLocationPermission();
  await NotificationService().initNotifications();

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _requestLocationPermission() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return;
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return;
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final lightTheme = _buildTheme(Brightness.light);
    final darkTheme = _buildTheme(Brightness.dark);

    return MaterialApp(
      title: 'UniVent',
      debugShowCheckedModeBanner: false, // Removes the green debug banner
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeProvider.darkTheme ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(), // Set the splash screen as the home
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseTheme = ThemeData(brightness: brightness);
    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Color(0xFF3A5FCD), // Darker, less saturated blue
            secondary: Color(0xFF3A5FCD),
            surface: Color(0xFF1E1E1E),
            onPrimary: Colors.white, // Text on primary color
            onSecondary: Colors.white, // Text on secondary color
            onSurface: Colors.white70)
        : const ColorScheme.light(
            primary: Color(0xFF00008B),
            secondary: Color(0xFF00008B),
            surface: Color(0xFFF0F2F5), // Light, blue-ish gray
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Color(0xFF1C1C1E)); // A darker color for text

    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        color: isDark ? colorScheme.surface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        shadowColor: isDark ? Colors.black.withAlpha(128) : Colors.black.withAlpha(26),
        margin: const EdgeInsets.symmetric(vertical: 8.0),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
       listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
      ),
       switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? Colors.grey.shade400 : Colors.grey.shade300;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary.withAlpha(128);
          }
          return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
        }),
      ),
    );
  }
}
