import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/song_provider.dart';
import 'providers/color_scheme_provider.dart';
import 'screens/home_screen.dart';
import 'services/database.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final database = AppDatabase();
  final storageService = StorageService(db: database);
  
  final colorSchemeProvider = ColorSchemeProvider();
  await colorSchemeProvider.load(); // Wait for preferences before starting app

  runApp(FlutterMusicApp(
    database: database,
    storageService: storageService,
    colorSchemeProvider: colorSchemeProvider,
  ));
}

class FlutterMusicApp extends StatelessWidget {
  final AppDatabase database;
  final StorageService storageService;
  final ColorSchemeProvider colorSchemeProvider;

  const FlutterMusicApp({
    super.key,
    required this.database,
    required this.storageService,
    required this.colorSchemeProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SongProvider(storage: storageService),
        ),
        ChangeNotifierProvider.value(
          value: colorSchemeProvider,
        ),
      ],
      child: Consumer<ColorSchemeProvider>(
        builder: (context, colorProvider, _) {
          return MaterialApp(
            title: 'Flutter Music',
            debugShowCheckedModeBanner: false,
            themeMode: colorProvider.themeMode,
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
