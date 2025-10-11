import 'package:final_project/Pages/splash_screen.dart';
import 'package:final_project/services/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the Google Maps renderer before the app starts.
  final GoogleMapsFlutterPlatform mapsImplementation = GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    try {
      await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
    } on PlatformException catch (e) {
      // On hot restart, the renderer may already be initialized.
      // This is not a fatal error, so we can ignore it. For any other
      // exception, we fall back to the legacy renderer.
      if (e.code != 'Renderer already initialized') {
         print("Failed to initialize with latest renderer: $e. Falling back to legacy.");
         await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.legacy);
      } else {
        print("Google Maps renderer already initialized. Ignoring on hot restart.");
      }
    }
  }

  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
    appleProvider: AppleProvider.debug,
  );
  await _requestLocationPermission();

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
            primary: Color(0xFF6792FF),
            secondary: Color(0xFF6792FF),
            surface: Color(0xFF1E1E1E),
            background: Color(0xFF121212),
            onPrimary: Colors.black,
            onSecondary: Colors.black,
            onSurface: Colors.white70,
            onBackground: Colors.white70)
        : const ColorScheme.light(
            primary: Color(0xFF00008B),
            secondary: Color(0xFF00008B),
            surface: Colors.white,
            background: Color(0xFFF3F4F8),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.black87,
            onBackground: Colors.black87);

    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
      bodyColor: colorScheme.onBackground,
      displayColor: colorScheme.onBackground,
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.background,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.onBackground,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        shadowColor: isDark ? Colors.black.withOpacity(0.5) : Colors.black.withOpacity(0.1),
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
        thumbColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return isDark ? Colors.grey.shade400 : Colors.grey.shade300;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color?>((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary.withOpacity(0.5);
          }
          return isDark ? Colors.grey.shade800 : Colors.grey.shade200;
        }),
      ),
    );
  }
}
