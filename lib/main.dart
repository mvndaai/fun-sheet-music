import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/song_provider.dart';
import 'providers/instrument_provider.dart';
import 'providers/keyboard_provider.dart';
import 'providers/sound_provider.dart';
import 'providers/payment_provider.dart';
import 'screens/home_screen.dart';
import 'services/database.dart';
import 'services/storage_service.dart';
import 'config/app_config.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showToast(String message, {bool isError = false}) {
  scaffoldMessengerKey.currentState?.clearSnackBars();
  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red.shade700 : null,
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: isError ? 4 : 2),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling for the Flutter framework
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER ERROR: ${details.exception}\n${details.stack}');
    // Avoid spamming snackbars for layout overflow errors
    if (details.exception is! FlutterError || !(details.exception as FlutterError).message.contains('A RenderFlex overflowed')) {
      showToast('App Error: ${details.exception}', isError: true);
    }
  };

  // Global error handling for asynchronous errors
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('ASYNC ERROR: $error\n$stack');
    showToast('Async Error: $error', isError: true);
    return true; // Error was handled
  };

  // Increase lifecycle channel buffer to prevent messages from being discarded during async initialization
  ServicesBinding.instance.channelBuffers.resize('flutter/lifecycle', 10);

  final database = AppDatabase();
  final storageService = StorageService(db: database);
  
  final instrumentProvider = InstrumentProvider();
  await instrumentProvider.load();
  
  final keyboardProvider = KeyboardProvider();
  await keyboardProvider.load();

  final soundProvider = SoundProvider();
  await soundProvider.load();

  // Ensure Google Fonts can fetch missing characters (like emojis/symbols) at runtime
  GoogleFonts.config.allowRuntimeFetching = true;

  runApp(FunSheetMusic(
    database: database,
    storageService: storageService,
    instrumentProvider: instrumentProvider,
    keyboardProvider: keyboardProvider,
    soundProvider: soundProvider,
  ));
}

// Helper function to create theme data with consistent configuration
ThemeData _buildTheme(Brightness brightness) {
  final baseTextTheme = brightness == Brightness.dark 
      ? ThemeData.dark().textTheme 
      : null;
  
  // Font fallback list for emoji and special characters
  const fontFallbacks = <String>[
    'NotoColorEmoji',
    'NotoSansSymbols',
    'NotoSansSymbols2',
    'NotoMusic',
  ];
  
  final textTheme = GoogleFonts.notoSansTextTheme(baseTextTheme);
  
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0),
      brightness: brightness,
    ),
    useMaterial3: true,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(fontFamilyFallback: fontFallbacks),
      displayMedium: textTheme.displayMedium?.copyWith(fontFamilyFallback: fontFallbacks),
      displaySmall: textTheme.displaySmall?.copyWith(fontFamilyFallback: fontFallbacks),
      headlineLarge: textTheme.headlineLarge?.copyWith(fontFamilyFallback: fontFallbacks),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontFamilyFallback: fontFallbacks),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontFamilyFallback: fontFallbacks),
      titleLarge: textTheme.titleLarge?.copyWith(fontFamilyFallback: fontFallbacks),
      titleMedium: textTheme.titleMedium?.copyWith(fontFamilyFallback: fontFallbacks),
      titleSmall: textTheme.titleSmall?.copyWith(fontFamilyFallback: fontFallbacks),
      bodyLarge: textTheme.bodyLarge?.copyWith(fontFamilyFallback: fontFallbacks),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontFamilyFallback: fontFallbacks),
      bodySmall: textTheme.bodySmall?.copyWith(fontFamilyFallback: fontFallbacks),
      labelLarge: textTheme.labelLarge?.copyWith(fontFamilyFallback: fontFallbacks),
      labelMedium: textTheme.labelMedium?.copyWith(fontFamilyFallback: fontFallbacks),
      labelSmall: textTheme.labelSmall?.copyWith(fontFamilyFallback: fontFallbacks),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: brightness == Brightness.light ? 2 : null,
    ),
    cardTheme: CardThemeData(
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
  );
}

class FunSheetMusic extends StatelessWidget {
  final AppDatabase database;
  final StorageService storageService;
  final InstrumentProvider instrumentProvider;
  final KeyboardProvider keyboardProvider;
  final SoundProvider soundProvider;

  const FunSheetMusic({
    super.key,
    required this.database,
    required this.storageService,
    required this.instrumentProvider,
    required this.keyboardProvider,
    required this.soundProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SongProvider(storage: storageService),
        ),
        ChangeNotifierProvider.value(
          value: instrumentProvider,
        ),
        ChangeNotifierProvider.value(
          value: keyboardProvider,
        ),
        ChangeNotifierProvider.value(
          value: soundProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => PaymentProvider(instrumentProvider: instrumentProvider),
        ),
      ],
      child: Consumer<InstrumentProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            scaffoldMessengerKey: scaffoldMessengerKey,
            title: AppConfig.title,
            debugShowCheckedModeBanner: false,
            themeMode: provider.themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            home: const SelectionArea(
              child: HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
