import 'package:drift/drift.dart';
import '../platform/platform.dart' as platform;

part 'database.g.dart';

/// Table definition for Songs
@DataClassName('SongDbEntity')
class Songs extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 255)();
  TextColumn get composer => text().nullable()();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get library => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get xmlContent => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class StringListConverter extends TypeConverter<List<String>, String> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) {
    if (fromDb.isEmpty) return [];
    return fromDb.split(',');
  }

  @override
  String toSql(List<String> value) {
    return value.join(',');
  }
}

@DriftDatabase(tables: [Songs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(platform.openDatabaseConnection());

  @override
  int get schemaVersion => 1;

  // --- DAO Methods ---

  Future<List<SongDbEntity>> getAllSongs() => select(songs).get();

  Future<int> insertSong(SongDbEntity song) => into(songs).insertOnConflictUpdate(song);

  Future<void> deleteSong(String id) => (delete(songs)..where((t) => t.id.equals(id))).go();

  Future<SongDbEntity?> getSongById(String id) => (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> updateSongTags(String id, List<String> tags) {
    return (update(songs)..where((t) => t.id.equals(id))).write(
      SongsCompanion(tags: Value(tags)),
    );
  }
}
