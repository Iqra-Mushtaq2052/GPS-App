// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MosquesTable extends Mosques with TableInfo<$MosquesTable, Mosque> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MosquesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _radiusMetersMeta = const VerificationMeta(
    'radiusMeters',
  );
  @override
  late final GeneratedColumn<int> radiusMeters = GeneratedColumn<int>(
    'radius_meters',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(40),
  );
  static const VerificationMeta _isEnabledMeta = const VerificationMeta(
    'isEnabled',
  );
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
    'is_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _supabaseIdMeta = const VerificationMeta(
    'supabaseId',
  );
  @override
  late final GeneratedColumn<String> supabaseId = GeneratedColumn<String>(
    'supabase_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shareCodeMeta = const VerificationMeta(
    'shareCode',
  );
  @override
  late final GeneratedColumn<String> shareCode = GeneratedColumn<String>(
    'share_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    latitude,
    longitude,
    radiusMeters,
    isEnabled,
    createdAt,
    supabaseId,
    shareCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mosques';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mosque> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('radius_meters')) {
      context.handle(
        _radiusMetersMeta,
        radiusMeters.isAcceptableOrUnknown(
          data['radius_meters']!,
          _radiusMetersMeta,
        ),
      );
    }
    if (data.containsKey('is_enabled')) {
      context.handle(
        _isEnabledMeta,
        isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('supabase_id')) {
      context.handle(
        _supabaseIdMeta,
        supabaseId.isAcceptableOrUnknown(data['supabase_id']!, _supabaseIdMeta),
      );
    }
    if (data.containsKey('share_code')) {
      context.handle(
        _shareCodeMeta,
        shareCode.isAcceptableOrUnknown(data['share_code']!, _shareCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Mosque map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mosque(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      radiusMeters: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}radius_meters'],
      )!,
      isEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_enabled'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      supabaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supabase_id'],
      ),
      shareCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_code'],
      ),
    );
  }

  @override
  $MosquesTable createAlias(String alias) {
    return $MosquesTable(attachedDatabase, alias);
  }
}

class Mosque extends DataClass implements Insertable<Mosque> {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isEnabled;
  final DateTime createdAt;
  final String? supabaseId;
  final String? shareCode;
  const Mosque({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isEnabled,
    required this.createdAt,
    this.supabaseId,
    this.shareCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['radius_meters'] = Variable<int>(radiusMeters);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || supabaseId != null) {
      map['supabase_id'] = Variable<String>(supabaseId);
    }
    if (!nullToAbsent || shareCode != null) {
      map['share_code'] = Variable<String>(shareCode);
    }
    return map;
  }

  MosquesCompanion toCompanion(bool nullToAbsent) {
    return MosquesCompanion(
      id: Value(id),
      name: Value(name),
      latitude: Value(latitude),
      longitude: Value(longitude),
      radiusMeters: Value(radiusMeters),
      isEnabled: Value(isEnabled),
      createdAt: Value(createdAt),
      supabaseId: supabaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(supabaseId),
      shareCode: shareCode == null && nullToAbsent
          ? const Value.absent()
          : Value(shareCode),
    );
  }

  factory Mosque.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mosque(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      radiusMeters: serializer.fromJson<int>(json['radiusMeters']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      supabaseId: serializer.fromJson<String?>(json['supabaseId']),
      shareCode: serializer.fromJson<String?>(json['shareCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'radiusMeters': serializer.toJson<int>(radiusMeters),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'supabaseId': serializer.toJson<String?>(supabaseId),
      'shareCode': serializer.toJson<String?>(shareCode),
    };
  }

  Mosque copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? isEnabled,
    DateTime? createdAt,
    Value<String?> supabaseId = const Value.absent(),
    Value<String?> shareCode = const Value.absent(),
  }) => Mosque(
    id: id ?? this.id,
    name: name ?? this.name,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    isEnabled: isEnabled ?? this.isEnabled,
    createdAt: createdAt ?? this.createdAt,
    supabaseId: supabaseId.present ? supabaseId.value : this.supabaseId,
    shareCode: shareCode.present ? shareCode.value : this.shareCode,
  );
  Mosque copyWithCompanion(MosquesCompanion data) {
    return Mosque(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      radiusMeters: data.radiusMeters.present
          ? data.radiusMeters.value
          : this.radiusMeters,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      supabaseId: data.supabaseId.present
          ? data.supabaseId.value
          : this.supabaseId,
      shareCode: data.shareCode.present ? data.shareCode.value : this.shareCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mosque(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('shareCode: $shareCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    latitude,
    longitude,
    radiusMeters,
    isEnabled,
    createdAt,
    supabaseId,
    shareCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mosque &&
          other.id == this.id &&
          other.name == this.name &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.radiusMeters == this.radiusMeters &&
          other.isEnabled == this.isEnabled &&
          other.createdAt == this.createdAt &&
          other.supabaseId == this.supabaseId &&
          other.shareCode == this.shareCode);
}

class MosquesCompanion extends UpdateCompanion<Mosque> {
  final Value<int> id;
  final Value<String> name;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<int> radiusMeters;
  final Value<bool> isEnabled;
  final Value<DateTime> createdAt;
  final Value<String?> supabaseId;
  final Value<String?> shareCode;
  const MosquesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.radiusMeters = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.shareCode = const Value.absent(),
  });
  MosquesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required double latitude,
    required double longitude,
    this.radiusMeters = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.supabaseId = const Value.absent(),
    this.shareCode = const Value.absent(),
  }) : name = Value(name),
       latitude = Value(latitude),
       longitude = Value(longitude);
  static Insertable<Mosque> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<int>? radiusMeters,
    Expression<bool>? isEnabled,
    Expression<DateTime>? createdAt,
    Expression<String>? supabaseId,
    Expression<String>? shareCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (radiusMeters != null) 'radius_meters': radiusMeters,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (supabaseId != null) 'supabase_id': supabaseId,
      if (shareCode != null) 'share_code': shareCode,
    });
  }

  MosquesCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<int>? radiusMeters,
    Value<bool>? isEnabled,
    Value<DateTime>? createdAt,
    Value<String?>? supabaseId,
    Value<String?>? shareCode,
  }) {
    return MosquesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      supabaseId: supabaseId ?? this.supabaseId,
      shareCode: shareCode ?? this.shareCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (radiusMeters.present) {
      map['radius_meters'] = Variable<int>(radiusMeters.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (supabaseId.present) {
      map['supabase_id'] = Variable<String>(supabaseId.value);
    }
    if (shareCode.present) {
      map['share_code'] = Variable<String>(shareCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MosquesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('radiusMeters: $radiusMeters, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('supabaseId: $supabaseId, ')
          ..write('shareCode: $shareCode')
          ..write(')'))
        .toString();
  }
}

class $LocalPrayerTimesTable extends LocalPrayerTimes
    with TableInfo<$LocalPrayerTimesTable, LocalPrayerTime> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPrayerTimesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mosqueIdMeta = const VerificationMeta(
    'mosqueId',
  );
  @override
  late final GeneratedColumn<int> mosqueId = GeneratedColumn<int>(
    'mosque_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES mosques (id)',
    ),
  );
  static const VerificationMeta _fajrMeta = const VerificationMeta('fajr');
  @override
  late final GeneratedColumn<String> fajr = GeneratedColumn<String>(
    'fajr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('05:00'),
  );
  static const VerificationMeta _dhuhrMeta = const VerificationMeta('dhuhr');
  @override
  late final GeneratedColumn<String> dhuhr = GeneratedColumn<String>(
    'dhuhr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('13:00'),
  );
  static const VerificationMeta _asrMeta = const VerificationMeta('asr');
  @override
  late final GeneratedColumn<String> asr = GeneratedColumn<String>(
    'asr',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('17:00'),
  );
  static const VerificationMeta _maghribMeta = const VerificationMeta(
    'maghrib',
  );
  @override
  late final GeneratedColumn<String> maghrib = GeneratedColumn<String>(
    'maghrib',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('18:30'),
  );
  static const VerificationMeta _ishaMeta = const VerificationMeta('isha');
  @override
  late final GeneratedColumn<String> isha = GeneratedColumn<String>(
    'isha',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('20:00'),
  );
  static const VerificationMeta _cloudMosqueIdMeta = const VerificationMeta(
    'cloudMosqueId',
  );
  @override
  late final GeneratedColumn<String> cloudMosqueId = GeneratedColumn<String>(
    'cloud_mosque_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mosqueId,
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
    cloudMosqueId,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_prayer_times';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPrayerTime> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mosque_id')) {
      context.handle(
        _mosqueIdMeta,
        mosqueId.isAcceptableOrUnknown(data['mosque_id']!, _mosqueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mosqueIdMeta);
    }
    if (data.containsKey('fajr')) {
      context.handle(
        _fajrMeta,
        fajr.isAcceptableOrUnknown(data['fajr']!, _fajrMeta),
      );
    }
    if (data.containsKey('dhuhr')) {
      context.handle(
        _dhuhrMeta,
        dhuhr.isAcceptableOrUnknown(data['dhuhr']!, _dhuhrMeta),
      );
    }
    if (data.containsKey('asr')) {
      context.handle(
        _asrMeta,
        asr.isAcceptableOrUnknown(data['asr']!, _asrMeta),
      );
    }
    if (data.containsKey('maghrib')) {
      context.handle(
        _maghribMeta,
        maghrib.isAcceptableOrUnknown(data['maghrib']!, _maghribMeta),
      );
    }
    if (data.containsKey('isha')) {
      context.handle(
        _ishaMeta,
        isha.isAcceptableOrUnknown(data['isha']!, _ishaMeta),
      );
    }
    if (data.containsKey('cloud_mosque_id')) {
      context.handle(
        _cloudMosqueIdMeta,
        cloudMosqueId.isAcceptableOrUnknown(
          data['cloud_mosque_id']!,
          _cloudMosqueIdMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPrayerTime map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPrayerTime(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mosqueId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mosque_id'],
      )!,
      fajr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fajr'],
      )!,
      dhuhr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dhuhr'],
      )!,
      asr: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asr'],
      )!,
      maghrib: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}maghrib'],
      )!,
      isha: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isha'],
      )!,
      cloudMosqueId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cloud_mosque_id'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocalPrayerTimesTable createAlias(String alias) {
    return $LocalPrayerTimesTable(attachedDatabase, alias);
  }
}

class LocalPrayerTime extends DataClass implements Insertable<LocalPrayerTime> {
  final int id;
  final int mosqueId;
  final String fajr;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String? cloudMosqueId;
  final DateTime updatedAt;
  const LocalPrayerTime({
    required this.id,
    required this.mosqueId,
    required this.fajr,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.cloudMosqueId,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mosque_id'] = Variable<int>(mosqueId);
    map['fajr'] = Variable<String>(fajr);
    map['dhuhr'] = Variable<String>(dhuhr);
    map['asr'] = Variable<String>(asr);
    map['maghrib'] = Variable<String>(maghrib);
    map['isha'] = Variable<String>(isha);
    if (!nullToAbsent || cloudMosqueId != null) {
      map['cloud_mosque_id'] = Variable<String>(cloudMosqueId);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  LocalPrayerTimesCompanion toCompanion(bool nullToAbsent) {
    return LocalPrayerTimesCompanion(
      id: Value(id),
      mosqueId: Value(mosqueId),
      fajr: Value(fajr),
      dhuhr: Value(dhuhr),
      asr: Value(asr),
      maghrib: Value(maghrib),
      isha: Value(isha),
      cloudMosqueId: cloudMosqueId == null && nullToAbsent
          ? const Value.absent()
          : Value(cloudMosqueId),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocalPrayerTime.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPrayerTime(
      id: serializer.fromJson<int>(json['id']),
      mosqueId: serializer.fromJson<int>(json['mosqueId']),
      fajr: serializer.fromJson<String>(json['fajr']),
      dhuhr: serializer.fromJson<String>(json['dhuhr']),
      asr: serializer.fromJson<String>(json['asr']),
      maghrib: serializer.fromJson<String>(json['maghrib']),
      isha: serializer.fromJson<String>(json['isha']),
      cloudMosqueId: serializer.fromJson<String?>(json['cloudMosqueId']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mosqueId': serializer.toJson<int>(mosqueId),
      'fajr': serializer.toJson<String>(fajr),
      'dhuhr': serializer.toJson<String>(dhuhr),
      'asr': serializer.toJson<String>(asr),
      'maghrib': serializer.toJson<String>(maghrib),
      'isha': serializer.toJson<String>(isha),
      'cloudMosqueId': serializer.toJson<String?>(cloudMosqueId),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  LocalPrayerTime copyWith({
    int? id,
    int? mosqueId,
    String? fajr,
    String? dhuhr,
    String? asr,
    String? maghrib,
    String? isha,
    Value<String?> cloudMosqueId = const Value.absent(),
    DateTime? updatedAt,
  }) => LocalPrayerTime(
    id: id ?? this.id,
    mosqueId: mosqueId ?? this.mosqueId,
    fajr: fajr ?? this.fajr,
    dhuhr: dhuhr ?? this.dhuhr,
    asr: asr ?? this.asr,
    maghrib: maghrib ?? this.maghrib,
    isha: isha ?? this.isha,
    cloudMosqueId: cloudMosqueId.present
        ? cloudMosqueId.value
        : this.cloudMosqueId,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocalPrayerTime copyWithCompanion(LocalPrayerTimesCompanion data) {
    return LocalPrayerTime(
      id: data.id.present ? data.id.value : this.id,
      mosqueId: data.mosqueId.present ? data.mosqueId.value : this.mosqueId,
      fajr: data.fajr.present ? data.fajr.value : this.fajr,
      dhuhr: data.dhuhr.present ? data.dhuhr.value : this.dhuhr,
      asr: data.asr.present ? data.asr.value : this.asr,
      maghrib: data.maghrib.present ? data.maghrib.value : this.maghrib,
      isha: data.isha.present ? data.isha.value : this.isha,
      cloudMosqueId: data.cloudMosqueId.present
          ? data.cloudMosqueId.value
          : this.cloudMosqueId,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPrayerTime(')
          ..write('id: $id, ')
          ..write('mosqueId: $mosqueId, ')
          ..write('fajr: $fajr, ')
          ..write('dhuhr: $dhuhr, ')
          ..write('asr: $asr, ')
          ..write('maghrib: $maghrib, ')
          ..write('isha: $isha, ')
          ..write('cloudMosqueId: $cloudMosqueId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mosqueId,
    fajr,
    dhuhr,
    asr,
    maghrib,
    isha,
    cloudMosqueId,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPrayerTime &&
          other.id == this.id &&
          other.mosqueId == this.mosqueId &&
          other.fajr == this.fajr &&
          other.dhuhr == this.dhuhr &&
          other.asr == this.asr &&
          other.maghrib == this.maghrib &&
          other.isha == this.isha &&
          other.cloudMosqueId == this.cloudMosqueId &&
          other.updatedAt == this.updatedAt);
}

class LocalPrayerTimesCompanion extends UpdateCompanion<LocalPrayerTime> {
  final Value<int> id;
  final Value<int> mosqueId;
  final Value<String> fajr;
  final Value<String> dhuhr;
  final Value<String> asr;
  final Value<String> maghrib;
  final Value<String> isha;
  final Value<String?> cloudMosqueId;
  final Value<DateTime> updatedAt;
  const LocalPrayerTimesCompanion({
    this.id = const Value.absent(),
    this.mosqueId = const Value.absent(),
    this.fajr = const Value.absent(),
    this.dhuhr = const Value.absent(),
    this.asr = const Value.absent(),
    this.maghrib = const Value.absent(),
    this.isha = const Value.absent(),
    this.cloudMosqueId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocalPrayerTimesCompanion.insert({
    this.id = const Value.absent(),
    required int mosqueId,
    this.fajr = const Value.absent(),
    this.dhuhr = const Value.absent(),
    this.asr = const Value.absent(),
    this.maghrib = const Value.absent(),
    this.isha = const Value.absent(),
    this.cloudMosqueId = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : mosqueId = Value(mosqueId);
  static Insertable<LocalPrayerTime> custom({
    Expression<int>? id,
    Expression<int>? mosqueId,
    Expression<String>? fajr,
    Expression<String>? dhuhr,
    Expression<String>? asr,
    Expression<String>? maghrib,
    Expression<String>? isha,
    Expression<String>? cloudMosqueId,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mosqueId != null) 'mosque_id': mosqueId,
      if (fajr != null) 'fajr': fajr,
      if (dhuhr != null) 'dhuhr': dhuhr,
      if (asr != null) 'asr': asr,
      if (maghrib != null) 'maghrib': maghrib,
      if (isha != null) 'isha': isha,
      if (cloudMosqueId != null) 'cloud_mosque_id': cloudMosqueId,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocalPrayerTimesCompanion copyWith({
    Value<int>? id,
    Value<int>? mosqueId,
    Value<String>? fajr,
    Value<String>? dhuhr,
    Value<String>? asr,
    Value<String>? maghrib,
    Value<String>? isha,
    Value<String?>? cloudMosqueId,
    Value<DateTime>? updatedAt,
  }) {
    return LocalPrayerTimesCompanion(
      id: id ?? this.id,
      mosqueId: mosqueId ?? this.mosqueId,
      fajr: fajr ?? this.fajr,
      dhuhr: dhuhr ?? this.dhuhr,
      asr: asr ?? this.asr,
      maghrib: maghrib ?? this.maghrib,
      isha: isha ?? this.isha,
      cloudMosqueId: cloudMosqueId ?? this.cloudMosqueId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mosqueId.present) {
      map['mosque_id'] = Variable<int>(mosqueId.value);
    }
    if (fajr.present) {
      map['fajr'] = Variable<String>(fajr.value);
    }
    if (dhuhr.present) {
      map['dhuhr'] = Variable<String>(dhuhr.value);
    }
    if (asr.present) {
      map['asr'] = Variable<String>(asr.value);
    }
    if (maghrib.present) {
      map['maghrib'] = Variable<String>(maghrib.value);
    }
    if (isha.present) {
      map['isha'] = Variable<String>(isha.value);
    }
    if (cloudMosqueId.present) {
      map['cloud_mosque_id'] = Variable<String>(cloudMosqueId.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPrayerTimesCompanion(')
          ..write('id: $id, ')
          ..write('mosqueId: $mosqueId, ')
          ..write('fajr: $fajr, ')
          ..write('dhuhr: $dhuhr, ')
          ..write('asr: $asr, ')
          ..write('maghrib: $maghrib, ')
          ..write('isha: $isha, ')
          ..write('cloudMosqueId: $cloudMosqueId, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MosquesTable mosques = $MosquesTable(this);
  late final $LocalPrayerTimesTable localPrayerTimes = $LocalPrayerTimesTable(
    this,
  );
  late final MosqueDao mosqueDao = MosqueDao(this as AppDatabase);
  late final LocalPrayerTimesDao localPrayerTimesDao = LocalPrayerTimesDao(
    this as AppDatabase,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mosques,
    localPrayerTimes,
  ];
}

typedef $$MosquesTableCreateCompanionBuilder =
    MosquesCompanion Function({
      Value<int> id,
      required String name,
      required double latitude,
      required double longitude,
      Value<int> radiusMeters,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<String?> supabaseId,
      Value<String?> shareCode,
    });
typedef $$MosquesTableUpdateCompanionBuilder =
    MosquesCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double> latitude,
      Value<double> longitude,
      Value<int> radiusMeters,
      Value<bool> isEnabled,
      Value<DateTime> createdAt,
      Value<String?> supabaseId,
      Value<String?> shareCode,
    });

final class $$MosquesTableReferences
    extends BaseReferences<_$AppDatabase, $MosquesTable, Mosque> {
  $$MosquesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalPrayerTimesTable, List<LocalPrayerTime>>
  _localPrayerTimesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.localPrayerTimes,
    aliasName: 'mosques__id__local_prayer_times__mosque_id',
  );

  $$LocalPrayerTimesTableProcessedTableManager get localPrayerTimesRefs {
    final manager = $$LocalPrayerTimesTableTableManager(
      $_db,
      $_db.localPrayerTimes,
    ).filter((f) => f.mosqueId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _localPrayerTimesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MosquesTableFilterComposer
    extends Composer<_$AppDatabase, $MosquesTable> {
  $$MosquesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localPrayerTimesRefs(
    Expression<bool> Function($$LocalPrayerTimesTableFilterComposer f) f,
  ) {
    final $$LocalPrayerTimesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPrayerTimes,
      getReferencedColumn: (t) => t.mosqueId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPrayerTimesTableFilterComposer(
            $db: $db,
            $table: $db.localPrayerTimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MosquesTableOrderingComposer
    extends Composer<_$AppDatabase, $MosquesTable> {
  $$MosquesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
    column: $table.isEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareCode => $composableBuilder(
    column: $table.shareCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MosquesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MosquesTable> {
  $$MosquesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<int> get radiusMeters => $composableBuilder(
    column: $table.radiusMeters,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get supabaseId => $composableBuilder(
    column: $table.supabaseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get shareCode =>
      $composableBuilder(column: $table.shareCode, builder: (column) => column);

  Expression<T> localPrayerTimesRefs<T extends Object>(
    Expression<T> Function($$LocalPrayerTimesTableAnnotationComposer a) f,
  ) {
    final $$LocalPrayerTimesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localPrayerTimes,
      getReferencedColumn: (t) => t.mosqueId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalPrayerTimesTableAnnotationComposer(
            $db: $db,
            $table: $db.localPrayerTimes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MosquesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MosquesTable,
          Mosque,
          $$MosquesTableFilterComposer,
          $$MosquesTableOrderingComposer,
          $$MosquesTableAnnotationComposer,
          $$MosquesTableCreateCompanionBuilder,
          $$MosquesTableUpdateCompanionBuilder,
          (Mosque, $$MosquesTableReferences),
          Mosque,
          PrefetchHooks Function({bool localPrayerTimesRefs})
        > {
  $$MosquesTableTableManager(_$AppDatabase db, $MosquesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MosquesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MosquesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MosquesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<int> radiusMeters = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String?> shareCode = const Value.absent(),
              }) => MosquesCompanion(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                isEnabled: isEnabled,
                createdAt: createdAt,
                supabaseId: supabaseId,
                shareCode: shareCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required double latitude,
                required double longitude,
                Value<int> radiusMeters = const Value.absent(),
                Value<bool> isEnabled = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> supabaseId = const Value.absent(),
                Value<String?> shareCode = const Value.absent(),
              }) => MosquesCompanion.insert(
                id: id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                radiusMeters: radiusMeters,
                isEnabled: isEnabled,
                createdAt: createdAt,
                supabaseId: supabaseId,
                shareCode: shareCode,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MosquesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localPrayerTimesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localPrayerTimesRefs) db.localPrayerTimes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localPrayerTimesRefs)
                    await $_getPrefetchedData<
                      Mosque,
                      $MosquesTable,
                      LocalPrayerTime
                    >(
                      currentTable: table,
                      referencedTable: $$MosquesTableReferences
                          ._localPrayerTimesRefsTable(db),
                      managerFromTypedResult: (p0) => $$MosquesTableReferences(
                        db,
                        table,
                        p0,
                      ).localPrayerTimesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mosqueId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MosquesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MosquesTable,
      Mosque,
      $$MosquesTableFilterComposer,
      $$MosquesTableOrderingComposer,
      $$MosquesTableAnnotationComposer,
      $$MosquesTableCreateCompanionBuilder,
      $$MosquesTableUpdateCompanionBuilder,
      (Mosque, $$MosquesTableReferences),
      Mosque,
      PrefetchHooks Function({bool localPrayerTimesRefs})
    >;
typedef $$LocalPrayerTimesTableCreateCompanionBuilder =
    LocalPrayerTimesCompanion Function({
      Value<int> id,
      required int mosqueId,
      Value<String> fajr,
      Value<String> dhuhr,
      Value<String> asr,
      Value<String> maghrib,
      Value<String> isha,
      Value<String?> cloudMosqueId,
      Value<DateTime> updatedAt,
    });
typedef $$LocalPrayerTimesTableUpdateCompanionBuilder =
    LocalPrayerTimesCompanion Function({
      Value<int> id,
      Value<int> mosqueId,
      Value<String> fajr,
      Value<String> dhuhr,
      Value<String> asr,
      Value<String> maghrib,
      Value<String> isha,
      Value<String?> cloudMosqueId,
      Value<DateTime> updatedAt,
    });

final class $$LocalPrayerTimesTableReferences
    extends
        BaseReferences<_$AppDatabase, $LocalPrayerTimesTable, LocalPrayerTime> {
  $$LocalPrayerTimesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MosquesTable _mosqueIdTable(_$AppDatabase db) =>
      db.mosques.createAlias('local_prayer_times__mosque_id__mosques__id');

  $$MosquesTableProcessedTableManager get mosqueId {
    final $_column = $_itemColumn<int>('mosque_id')!;

    final manager = $$MosquesTableTableManager(
      $_db,
      $_db.mosques,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mosqueIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalPrayerTimesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalPrayerTimesTable> {
  $$LocalPrayerTimesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fajr => $composableBuilder(
    column: $table.fajr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dhuhr => $composableBuilder(
    column: $table.dhuhr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get asr => $composableBuilder(
    column: $table.asr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get maghrib => $composableBuilder(
    column: $table.maghrib,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isha => $composableBuilder(
    column: $table.isha,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cloudMosqueId => $composableBuilder(
    column: $table.cloudMosqueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MosquesTableFilterComposer get mosqueId {
    final $$MosquesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mosqueId,
      referencedTable: $db.mosques,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MosquesTableFilterComposer(
            $db: $db,
            $table: $db.mosques,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPrayerTimesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalPrayerTimesTable> {
  $$LocalPrayerTimesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fajr => $composableBuilder(
    column: $table.fajr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dhuhr => $composableBuilder(
    column: $table.dhuhr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get asr => $composableBuilder(
    column: $table.asr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get maghrib => $composableBuilder(
    column: $table.maghrib,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isha => $composableBuilder(
    column: $table.isha,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cloudMosqueId => $composableBuilder(
    column: $table.cloudMosqueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MosquesTableOrderingComposer get mosqueId {
    final $$MosquesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mosqueId,
      referencedTable: $db.mosques,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MosquesTableOrderingComposer(
            $db: $db,
            $table: $db.mosques,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPrayerTimesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalPrayerTimesTable> {
  $$LocalPrayerTimesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fajr =>
      $composableBuilder(column: $table.fajr, builder: (column) => column);

  GeneratedColumn<String> get dhuhr =>
      $composableBuilder(column: $table.dhuhr, builder: (column) => column);

  GeneratedColumn<String> get asr =>
      $composableBuilder(column: $table.asr, builder: (column) => column);

  GeneratedColumn<String> get maghrib =>
      $composableBuilder(column: $table.maghrib, builder: (column) => column);

  GeneratedColumn<String> get isha =>
      $composableBuilder(column: $table.isha, builder: (column) => column);

  GeneratedColumn<String> get cloudMosqueId => $composableBuilder(
    column: $table.cloudMosqueId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$MosquesTableAnnotationComposer get mosqueId {
    final $$MosquesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mosqueId,
      referencedTable: $db.mosques,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MosquesTableAnnotationComposer(
            $db: $db,
            $table: $db.mosques,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalPrayerTimesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalPrayerTimesTable,
          LocalPrayerTime,
          $$LocalPrayerTimesTableFilterComposer,
          $$LocalPrayerTimesTableOrderingComposer,
          $$LocalPrayerTimesTableAnnotationComposer,
          $$LocalPrayerTimesTableCreateCompanionBuilder,
          $$LocalPrayerTimesTableUpdateCompanionBuilder,
          (LocalPrayerTime, $$LocalPrayerTimesTableReferences),
          LocalPrayerTime,
          PrefetchHooks Function({bool mosqueId})
        > {
  $$LocalPrayerTimesTableTableManager(
    _$AppDatabase db,
    $LocalPrayerTimesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPrayerTimesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPrayerTimesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPrayerTimesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mosqueId = const Value.absent(),
                Value<String> fajr = const Value.absent(),
                Value<String> dhuhr = const Value.absent(),
                Value<String> asr = const Value.absent(),
                Value<String> maghrib = const Value.absent(),
                Value<String> isha = const Value.absent(),
                Value<String?> cloudMosqueId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalPrayerTimesCompanion(
                id: id,
                mosqueId: mosqueId,
                fajr: fajr,
                dhuhr: dhuhr,
                asr: asr,
                maghrib: maghrib,
                isha: isha,
                cloudMosqueId: cloudMosqueId,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mosqueId,
                Value<String> fajr = const Value.absent(),
                Value<String> dhuhr = const Value.absent(),
                Value<String> asr = const Value.absent(),
                Value<String> maghrib = const Value.absent(),
                Value<String> isha = const Value.absent(),
                Value<String?> cloudMosqueId = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => LocalPrayerTimesCompanion.insert(
                id: id,
                mosqueId: mosqueId,
                fajr: fajr,
                dhuhr: dhuhr,
                asr: asr,
                maghrib: maghrib,
                isha: isha,
                cloudMosqueId: cloudMosqueId,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalPrayerTimesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mosqueId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mosqueId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mosqueId,
                                referencedTable:
                                    $$LocalPrayerTimesTableReferences
                                        ._mosqueIdTable(db),
                                referencedColumn:
                                    $$LocalPrayerTimesTableReferences
                                        ._mosqueIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LocalPrayerTimesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalPrayerTimesTable,
      LocalPrayerTime,
      $$LocalPrayerTimesTableFilterComposer,
      $$LocalPrayerTimesTableOrderingComposer,
      $$LocalPrayerTimesTableAnnotationComposer,
      $$LocalPrayerTimesTableCreateCompanionBuilder,
      $$LocalPrayerTimesTableUpdateCompanionBuilder,
      (LocalPrayerTime, $$LocalPrayerTimesTableReferences),
      LocalPrayerTime,
      PrefetchHooks Function({bool mosqueId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MosquesTableTableManager get mosques =>
      $$MosquesTableTableManager(_db, _db.mosques);
  $$LocalPrayerTimesTableTableManager get localPrayerTimes =>
      $$LocalPrayerTimesTableTableManager(_db, _db.localPrayerTimes);
}
