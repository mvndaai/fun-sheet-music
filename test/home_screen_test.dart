import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fun_sheet_music/providers/song_provider.dart';
import 'package:fun_sheet_music/providers/instrument_provider.dart';
import 'package:fun_sheet_music/screens/home_screen.dart';
import 'package:fun_sheet_music/services/database.dart';
import 'package:fun_sheet_music/services/storage_service.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase database;
  late StorageService storageService;
  late InstrumentProvider instrumentProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    
    // Use an in-memory database for testing
    database = AppDatabase.forTesting(NativeDatabase.memory());
    storageService = StorageService(db: database);
    
    instrumentProvider = InstrumentProvider();
    await instrumentProvider.load();
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('HomeScreen renders and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SongProvider(storage: storageService),
          ),
          ChangeNotifierProvider.value(
            value: instrumentProvider,
          ),
        ],
        child: const MaterialApp(
          home: HomeScreen(),
        ),
      ),
    );

    // Wait for the asynchronous loadSongs() call to complete
    await tester.pump(); // Triggers postFrameCallback
    // Wait for async work. Using a loop with pump(duration) instead of pumpAndSettle
    // to avoid timeout issues with infinite animations.
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify title is present
    expect(find.text('🎵 My Songs'), findsOneWidget);
  });
}
