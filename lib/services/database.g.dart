// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SongsTable extends Songs with TableInfo<$SongsTable, SongDbEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      additionalChecks:
          GeneratedColumn.checkTextLength(minTextLength: 1, maxTextLength: 255),
      type: DriftSqlType.string,
      requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _composerMeta =
      const VerificationMeta('composer');
  @override
  late final GeneratedColumn<String> composer = GeneratedColumn<String>(
      'composer', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<List<String>, String> tags =
      GeneratedColumn<String>('tags', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<List<String>>($SongsTable.$convertertags);
  static const VerificationMeta _libraryMeta =
      const VerificationMeta('library');
  @override
  late final GeneratedColumn<String> library = GeneratedColumn<String>(
      'library', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _sourceUrlMeta =
      const VerificationMeta('sourceUrl');
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
      'source_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _xmlContentMeta =
      const VerificationMeta('xmlContent');
  @override
  late final GeneratedColumn<String> xmlContent = GeneratedColumn<String>(
      'xml_content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        icon,
        composer,
        tags,
        library,
        localPath,
        sourceUrl,
        createdAt,
        xmlContent
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'songs';
  @override
  VerificationContext validateIntegrity(Insertable<SongDbEntity> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    }
    if (data.containsKey('composer')) {
      context.handle(_composerMeta,
          composer.isAcceptableOrUnknown(data['composer']!, _composerMeta));
    }
    if (data.containsKey('library')) {
      context.handle(_libraryMeta,
          library.isAcceptableOrUnknown(data['library']!, _libraryMeta));
    } else if (isInserting) {
      context.missing(_libraryMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('source_url')) {
      context.handle(_sourceUrlMeta,
          sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('xml_content')) {
      context.handle(
          _xmlContentMeta,
          xmlContent.isAcceptableOrUnknown(
              data['xml_content']!, _xmlContentMeta));
    } else if (isInserting) {
      context.missing(_xmlContentMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SongDbEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SongDbEntity(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      composer: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}composer']),
      tags: $SongsTable.$convertertags.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags'])!),
      library: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}library'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      sourceUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source_url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      xmlContent: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}xml_content'])!,
    );
  }

  @override
  $SongsTable createAlias(String alias) {
    return $SongsTable(attachedDatabase, alias);
  }

  static TypeConverter<List<String>, String> $convertertags =
      const StringListConverter();
}

class SongDbEntity extends DataClass implements Insertable<SongDbEntity> {
  final String id;
  final String title;
  final String icon;
  final String? composer;
  final List<String> tags;
  final String library;
  final String? localPath;
  final String? sourceUrl;
  final DateTime createdAt;
  final String xmlContent;
  const SongDbEntity(
      {required this.id,
      required this.title,
      required this.icon,
      this.composer,
      required this.tags,
      required this.library,
      this.localPath,
      this.sourceUrl,
      required this.createdAt,
      required this.xmlContent});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['icon'] = Variable<String>(icon);
    if (!nullToAbsent || composer != null) {
      map['composer'] = Variable<String>(composer);
    }
    {
      map['tags'] = Variable<String>($SongsTable.$convertertags.toSql(tags));
    }
    map['library'] = Variable<String>(library);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    if (!nullToAbsent || sourceUrl != null) {
      map['source_url'] = Variable<String>(sourceUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['xml_content'] = Variable<String>(xmlContent);
    return map;
  }

  SongsCompanion toCompanion(bool nullToAbsent) {
    return SongsCompanion(
      id: Value(id),
      title: Value(title),
      icon: Value(icon),
      composer: composer == null && nullToAbsent
          ? const Value.absent()
          : Value(composer),
      tags: Value(tags),
      library: Value(library),
      localPath: localPath == null && nullToAbsent
          ? const Value.absent()
          : Value(localPath),
      sourceUrl: sourceUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceUrl),
      createdAt: Value(createdAt),
      xmlContent: Value(xmlContent),
    );
  }

  factory SongDbEntity.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SongDbEntity(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      icon: serializer.fromJson<String>(json['icon']),
      composer: serializer.fromJson<String?>(json['composer']),
      tags: serializer.fromJson<List<String>>(json['tags']),
      library: serializer.fromJson<String>(json['library']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      sourceUrl: serializer.fromJson<String?>(json['sourceUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      xmlContent: serializer.fromJson<String>(json['xmlContent']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'icon': serializer.toJson<String>(icon),
      'composer': serializer.toJson<String?>(composer),
      'tags': serializer.toJson<List<String>>(tags),
      'library': serializer.toJson<String>(library),
      'localPath': serializer.toJson<String?>(localPath),
      'sourceUrl': serializer.toJson<String?>(sourceUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'xmlContent': serializer.toJson<String>(xmlContent),
    };
  }

  SongDbEntity copyWith(
          {String? id,
          String? title,
          String? icon,
          Value<String?> composer = const Value.absent(),
          List<String>? tags,
          String? library,
          Value<String?> localPath = const Value.absent(),
          Value<String?> sourceUrl = const Value.absent(),
          DateTime? createdAt,
          String? xmlContent}) =>
      SongDbEntity(
        id: id ?? this.id,
        title: title ?? this.title,
        icon: icon ?? this.icon,
        composer: composer.present ? composer.value : this.composer,
        tags: tags ?? this.tags,
        library: library ?? this.library,
        localPath: localPath.present ? localPath.value : this.localPath,
        sourceUrl: sourceUrl.present ? sourceUrl.value : this.sourceUrl,
        createdAt: createdAt ?? this.createdAt,
        xmlContent: xmlContent ?? this.xmlContent,
      );
  SongDbEntity copyWithCompanion(SongsCompanion data) {
    return SongDbEntity(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      icon: data.icon.present ? data.icon.value : this.icon,
      composer: data.composer.present ? data.composer.value : this.composer,
      tags: data.tags.present ? data.tags.value : this.tags,
      library: data.library.present ? data.library.value : this.library,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      xmlContent:
          data.xmlContent.present ? data.xmlContent.value : this.xmlContent,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SongDbEntity(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('composer: $composer, ')
          ..write('tags: $tags, ')
          ..write('library: $library, ')
          ..write('localPath: $localPath, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('xmlContent: $xmlContent')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, icon, composer, tags, library,
      localPath, sourceUrl, createdAt, xmlContent);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SongDbEntity &&
          other.id == this.id &&
          other.title == this.title &&
          other.icon == this.icon &&
          other.composer == this.composer &&
          other.tags == this.tags &&
          other.library == this.library &&
          other.localPath == this.localPath &&
          other.sourceUrl == this.sourceUrl &&
          other.createdAt == this.createdAt &&
          other.xmlContent == this.xmlContent);
}

class SongsCompanion extends UpdateCompanion<SongDbEntity> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> icon;
  final Value<String?> composer;
  final Value<List<String>> tags;
  final Value<String> library;
  final Value<String?> localPath;
  final Value<String?> sourceUrl;
  final Value<DateTime> createdAt;
  final Value<String> xmlContent;
  final Value<int> rowid;
  const SongsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.icon = const Value.absent(),
    this.composer = const Value.absent(),
    this.tags = const Value.absent(),
    this.library = const Value.absent(),
    this.localPath = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.xmlContent = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SongsCompanion.insert({
    required String id,
    required String title,
    this.icon = const Value.absent(),
    this.composer = const Value.absent(),
    required List<String> tags,
    required String library,
    this.localPath = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    required DateTime createdAt,
    required String xmlContent,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        tags = Value(tags),
        library = Value(library),
        createdAt = Value(createdAt),
        xmlContent = Value(xmlContent);
  static Insertable<SongDbEntity> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? icon,
    Expression<String>? composer,
    Expression<String>? tags,
    Expression<String>? library,
    Expression<String>? localPath,
    Expression<String>? sourceUrl,
    Expression<DateTime>? createdAt,
    Expression<String>? xmlContent,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (icon != null) 'icon': icon,
      if (composer != null) 'composer': composer,
      if (tags != null) 'tags': tags,
      if (library != null) 'library': library,
      if (localPath != null) 'local_path': localPath,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (xmlContent != null) 'xml_content': xmlContent,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SongsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? icon,
      Value<String?>? composer,
      Value<List<String>>? tags,
      Value<String>? library,
      Value<String?>? localPath,
      Value<String?>? sourceUrl,
      Value<DateTime>? createdAt,
      Value<String>? xmlContent,
      Value<int>? rowid}) {
    return SongsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      composer: composer ?? this.composer,
      tags: tags ?? this.tags,
      library: library ?? this.library,
      localPath: localPath ?? this.localPath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      xmlContent: xmlContent ?? this.xmlContent,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (composer.present) {
      map['composer'] = Variable<String>(composer.value);
    }
    if (tags.present) {
      map['tags'] =
          Variable<String>($SongsTable.$convertertags.toSql(tags.value));
    }
    if (library.present) {
      map['library'] = Variable<String>(library.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (xmlContent.present) {
      map['xml_content'] = Variable<String>(xmlContent.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SongsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('icon: $icon, ')
          ..write('composer: $composer, ')
          ..write('tags: $tags, ')
          ..write('library: $library, ')
          ..write('localPath: $localPath, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('xmlContent: $xmlContent, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SongsTable songs = $SongsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [songs];
}

typedef $$SongsTableCreateCompanionBuilder = SongsCompanion Function({
  required String id,
  required String title,
  Value<String> icon,
  Value<String?> composer,
  required List<String> tags,
  required String library,
  Value<String?> localPath,
  Value<String?> sourceUrl,
  required DateTime createdAt,
  required String xmlContent,
  Value<int> rowid,
});
typedef $$SongsTableUpdateCompanionBuilder = SongsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> icon,
  Value<String?> composer,
  Value<List<String>> tags,
  Value<String> library,
  Value<String?> localPath,
  Value<String?> sourceUrl,
  Value<DateTime> createdAt,
  Value<String> xmlContent,
  Value<int> rowid,
});

class $$SongsTableFilterComposer extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get composer => $composableBuilder(
      column: $table.composer, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<List<String>, List<String>, String> get tags =>
      $composableBuilder(
          column: $table.tags,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get library => $composableBuilder(
      column: $table.library, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get xmlContent => $composableBuilder(
      column: $table.xmlContent, builder: (column) => ColumnFilters(column));
}

class $$SongsTableOrderingComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get composer => $composableBuilder(
      column: $table.composer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get library => $composableBuilder(
      column: $table.library, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
      column: $table.sourceUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get xmlContent => $composableBuilder(
      column: $table.xmlContent, builder: (column) => ColumnOrderings(column));
}

class $$SongsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SongsTable> {
  $$SongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get composer =>
      $composableBuilder(column: $table.composer, builder: (column) => column);

  GeneratedColumnWithTypeConverter<List<String>, String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get library =>
      $composableBuilder(column: $table.library, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get xmlContent => $composableBuilder(
      column: $table.xmlContent, builder: (column) => column);
}

class $$SongsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SongsTable,
    SongDbEntity,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (SongDbEntity, BaseReferences<_$AppDatabase, $SongsTable, SongDbEntity>),
    SongDbEntity,
    PrefetchHooks Function()> {
  $$SongsTableTableManager(_$AppDatabase db, $SongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SongsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SongsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<String?> composer = const Value.absent(),
            Value<List<String>> tags = const Value.absent(),
            Value<String> library = const Value.absent(),
            Value<String?> localPath = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<String> xmlContent = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SongsCompanion(
            id: id,
            title: title,
            icon: icon,
            composer: composer,
            tags: tags,
            library: library,
            localPath: localPath,
            sourceUrl: sourceUrl,
            createdAt: createdAt,
            xmlContent: xmlContent,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<String> icon = const Value.absent(),
            Value<String?> composer = const Value.absent(),
            required List<String> tags,
            required String library,
            Value<String?> localPath = const Value.absent(),
            Value<String?> sourceUrl = const Value.absent(),
            required DateTime createdAt,
            required String xmlContent,
            Value<int> rowid = const Value.absent(),
          }) =>
              SongsCompanion.insert(
            id: id,
            title: title,
            icon: icon,
            composer: composer,
            tags: tags,
            library: library,
            localPath: localPath,
            sourceUrl: sourceUrl,
            createdAt: createdAt,
            xmlContent: xmlContent,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SongsTable,
    SongDbEntity,
    $$SongsTableFilterComposer,
    $$SongsTableOrderingComposer,
    $$SongsTableAnnotationComposer,
    $$SongsTableCreateCompanionBuilder,
    $$SongsTableUpdateCompanionBuilder,
    (SongDbEntity, BaseReferences<_$AppDatabase, $SongsTable, SongDbEntity>),
    SongDbEntity,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SongsTableTableManager get songs =>
      $$SongsTableTableManager(_db, _db.songs);
}
