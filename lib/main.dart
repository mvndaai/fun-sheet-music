import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/song_provider.dart';
import 'providers/color_scheme_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FlutterMusicApp());
}

class FlutterMusicApp extends StatelessWidget {
  const FlutterMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SongProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final p = ColorSchemeProvider();
            p.load(); // load persisted scheme & label toggle
            return p;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 2,
          ),
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
