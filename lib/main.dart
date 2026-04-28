import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/song_provider.dart';
import 'providers/instrument_provider.dart';
import 'providers/keyboard_provider.dart';
import 'screens/home_screen.dart';
import 'services/database.dart';
import 'services/storage_service.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Increase lifecycle channel buffer to prevent messages from being discarded during async initialization
  ServicesBinding.instance.channelBuffers.resize('flutter/lifecycle', 10);

  final database = AppDatabase();
  final storageService = StorageService(db: database);
  
  final instrumentProvider = InstrumentProvider();
  await instrumentProvider.load();
  
  final keyboardProvider = KeyboardProvider();
  await keyboardProvider.load();

  // Ensure Google Fonts can fetch missing characters (like emojis/symbols) at runtime
  GoogleFonts.config.allowRuntimeFetching = true;

  runApp(FunSheetMusicApp(
    database: database,
    storageService: storageService,
    instrumentProvider: instrumentProvider,
    keyboardProvider: keyboardProvider,
  ));
}

class FunSheetMusicApp extends StatelessWidget {
  final AppDatabase database;
  final StorageService storageService;
  final InstrumentProvider instrumentProvider;
  final KeyboardProvider keyboardProvider;

  const FunSheetMusicApp({
    super.key,
    required this.database,
    required this.storageService,
    required this.instrumentProvider,
    required this.keyboardProvider,
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
      ],
      child: Consumer<InstrumentProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            themeMode: provider.themeMode,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1565C0),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 2,
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
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1565C0),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              textTheme: GoogleFonts.notoSansTextTheme(ThemeData.dark().textTheme),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
              ),
            ),
            home: const SelectionArea(
              child: HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
