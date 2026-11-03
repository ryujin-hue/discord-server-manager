// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UploadQueueItemsTable extends UploadQueueItems
    with TableInfo<$UploadQueueItemsTable, UploadQueueItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UploadQueueItemsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<String> destinationId = GeneratedColumn<String>(
    'destination_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationNameMeta = const VerificationMeta(
    'destinationName',
  );
  @override
  late final GeneratedColumn<String> destinationName = GeneratedColumn<String>(
    'destination_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourcePathMeta = const VerificationMeta(
    'sourcePath',
  );
  @override
  late final GeneratedColumn<String> sourcePath = GeneratedColumn<String>(
    'source_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta(
    'progress',
  );
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta(
    'finishedAt',
  );
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    destinationId,
    destinationName,
    sourcePath,
    fileName,
    sizeBytes,
    mimeType,
    kind,
    state,
    progress,
    createdAt,
    startedAt,
    finishedAt,
    errorCode,
    errorMessage,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upload_queue_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<UploadQueueItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationIdMeta);
    }
    if (data.containsKey('destination_name')) {
      context.handle(
        _destinationNameMeta,
        destinationName.isAcceptableOrUnknown(
          data['destination_name']!,
          _destinationNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationNameMeta);
    }
    if (data.containsKey('source_path')) {
      context.handle(
        _sourcePathMeta,
        sourcePath.isAcceptableOrUnknown(data['source_path']!, _sourcePathMeta),
      );
    } else if (isInserting) {
      context.missing(_sourcePathMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('progress')) {
      context.handle(
        _progressMeta,
        progress.isAcceptableOrUnknown(data['progress']!, _progressMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('finished_at')) {
      context.handle(
        _finishedAtMeta,
        finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UploadQueueItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UploadQueueItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_id'],
      )!,
      destinationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_name'],
      )!,
      sourcePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_path'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      progress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}progress'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      ),
      finishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}finished_at'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $UploadQueueItemsTable createAlias(String alias) {
    return $UploadQueueItemsTable(attachedDatabase, alias);
  }
}

class UploadQueueItem extends DataClass implements Insertable<UploadQueueItem> {
  final int id;
  final String destinationId;
  final String destinationName;
  final String sourcePath;
  final String fileName;
  final int sizeBytes;
  final String? mimeType;
  final String kind;
  final String state;
  final double progress;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorCode;
  final String? errorMessage;
  final int position;
  const UploadQueueItem({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.sourcePath,
    required this.fileName,
    required this.sizeBytes,
    this.mimeType,
    required this.kind,
    required this.state,
    required this.progress,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.errorCode,
    this.errorMessage,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['destination_id'] = Variable<String>(destinationId);
    map['destination_name'] = Variable<String>(destinationName);
    map['source_path'] = Variable<String>(sourcePath);
    map['file_name'] = Variable<String>(fileName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    map['progress'] = Variable<double>(progress);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<DateTime>(startedAt);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['position'] = Variable<int>(position);
    return map;
  }

  UploadQueueItemsCompanion toCompanion(bool nullToAbsent) {
    return UploadQueueItemsCompanion(
      id: Value(id),
      destinationId: Value(destinationId),
      destinationName: Value(destinationName),
      sourcePath: Value(sourcePath),
      fileName: Value(fileName),
      sizeBytes: Value(sizeBytes),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      kind: Value(kind),
      state: Value(state),
      progress: Value(progress),
      createdAt: Value(createdAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      finishedAt: finishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(finishedAt),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      position: Value(position),
    );
  }

  factory UploadQueueItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UploadQueueItem(
      id: serializer.fromJson<int>(json['id']),
      destinationId: serializer.fromJson<String>(json['destinationId']),
      destinationName: serializer.fromJson<String>(json['destinationName']),
      sourcePath: serializer.fromJson<String>(json['sourcePath']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      progress: serializer.fromJson<double>(json['progress']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      startedAt: serializer.fromJson<DateTime?>(json['startedAt']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'destinationId': serializer.toJson<String>(destinationId),
      'destinationName': serializer.toJson<String>(destinationName),
      'sourcePath': serializer.toJson<String>(sourcePath),
      'fileName': serializer.toJson<String>(fileName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'mimeType': serializer.toJson<String?>(mimeType),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'progress': serializer.toJson<double>(progress),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'startedAt': serializer.toJson<DateTime?>(startedAt),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
      'errorCode': serializer.toJson<String?>(errorCode),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'position': serializer.toJson<int>(position),
    };
  }

  UploadQueueItem copyWith({
    int? id,
    String? destinationId,
    String? destinationName,
    String? sourcePath,
    String? fileName,
    int? sizeBytes,
    Value<String?> mimeType = const Value.absent(),
    String? kind,
    String? state,
    double? progress,
    DateTime? createdAt,
    Value<DateTime?> startedAt = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
    Value<String?> errorMessage = const Value.absent(),
    int? position,
  }) => UploadQueueItem(
    id: id ?? this.id,
    destinationId: destinationId ?? this.destinationId,
    destinationName: destinationName ?? this.destinationName,
    sourcePath: sourcePath ?? this.sourcePath,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    progress: progress ?? this.progress,
    createdAt: createdAt ?? this.createdAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    position: position ?? this.position,
  );
  UploadQueueItem copyWithCompanion(UploadQueueItemsCompanion data) {
    return UploadQueueItem(
      id: data.id.present ? data.id.value : this.id,
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      destinationName: data.destinationName.present
          ? data.destinationName.value
          : this.destinationName,
      sourcePath: data.sourcePath.present
          ? data.sourcePath.value
          : this.sourcePath,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      progress: data.progress.present ? data.progress.value : this.progress,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      finishedAt: data.finishedAt.present
          ? data.finishedAt.value
          : this.finishedAt,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueItem(')
          ..write('id: $id, ')
          ..write('destinationId: $destinationId, ')
          ..write('destinationName: $destinationName, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    destinationId,
    destinationName,
    sourcePath,
    fileName,
    sizeBytes,
    mimeType,
    kind,
    state,
    progress,
    createdAt,
    startedAt,
    finishedAt,
    errorCode,
    errorMessage,
    position,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadQueueItem &&
          other.id == this.id &&
          other.destinationId == this.destinationId &&
          other.destinationName == this.destinationName &&
          other.sourcePath == this.sourcePath &&
          other.fileName == this.fileName &&
          other.sizeBytes == this.sizeBytes &&
          other.mimeType == this.mimeType &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.progress == this.progress &&
          other.createdAt == this.createdAt &&
          other.startedAt == this.startedAt &&
          other.finishedAt == this.finishedAt &&
          other.errorCode == this.errorCode &&
          other.errorMessage == this.errorMessage &&
          other.position == this.position);
}

class UploadQueueItemsCompanion extends UpdateCompanion<UploadQueueItem> {
  final Value<int> id;
  final Value<String> destinationId;
  final Value<String> destinationName;
  final Value<String> sourcePath;
  final Value<String> fileName;
  final Value<int> sizeBytes;
  final Value<String?> mimeType;
  final Value<String> kind;
  final Value<String> state;
  final Value<double> progress;
  final Value<DateTime> createdAt;
  final Value<DateTime?> startedAt;
  final Value<DateTime?> finishedAt;
  final Value<String?> errorCode;
  final Value<String?> errorMessage;
  final Value<int> position;
  const UploadQueueItemsCompanion({
    this.id = const Value.absent(),
    this.destinationId = const Value.absent(),
    this.destinationName = const Value.absent(),
    this.sourcePath = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.progress = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.position = const Value.absent(),
  });
  UploadQueueItemsCompanion.insert({
    this.id = const Value.absent(),
    required String destinationId,
    required String destinationName,
    required String sourcePath,
    required String fileName,
    required int sizeBytes,
    this.mimeType = const Value.absent(),
    required String kind,
    required String state,
    this.progress = const Value.absent(),
    required DateTime createdAt,
    this.startedAt = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.position = const Value.absent(),
  }) : destinationId = Value(destinationId),
       destinationName = Value(destinationName),
       sourcePath = Value(sourcePath),
       fileName = Value(fileName),
       sizeBytes = Value(sizeBytes),
       kind = Value(kind),
       state = Value(state),
       createdAt = Value(createdAt);
  static Insertable<UploadQueueItem> custom({
    Expression<int>? id,
    Expression<String>? destinationId,
    Expression<String>? destinationName,
    Expression<String>? sourcePath,
    Expression<String>? fileName,
    Expression<int>? sizeBytes,
    Expression<String>? mimeType,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<double>? progress,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? finishedAt,
    Expression<String>? errorCode,
    Expression<String>? errorMessage,
    Expression<int>? position,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (destinationId != null) 'destination_id': destinationId,
      if (destinationName != null) 'destination_name': destinationName,
      if (sourcePath != null) 'source_path': sourcePath,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mimeType != null) 'mime_type': mimeType,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (progress != null) 'progress': progress,
      if (createdAt != null) 'created_at': createdAt,
      if (startedAt != null) 'started_at': startedAt,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
      if (position != null) 'position': position,
    });
  }

  UploadQueueItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? destinationId,
    Value<String>? destinationName,
    Value<String>? sourcePath,
    Value<String>? fileName,
    Value<int>? sizeBytes,
    Value<String?>? mimeType,
    Value<String>? kind,
    Value<String>? state,
    Value<double>? progress,
    Value<DateTime>? createdAt,
    Value<DateTime?>? startedAt,
    Value<DateTime?>? finishedAt,
    Value<String?>? errorCode,
    Value<String?>? errorMessage,
    Value<int>? position,
  }) {
    return UploadQueueItemsCompanion(
      id: id ?? this.id,
      destinationId: destinationId ?? this.destinationId,
      destinationName: destinationName ?? this.destinationName,
      sourcePath: sourcePath ?? this.sourcePath,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      position: position ?? this.position,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (destinationId.present) {
      map['destination_id'] = Variable<String>(destinationId.value);
    }
    if (destinationName.present) {
      map['destination_name'] = Variable<String>(destinationName.value);
    }
    if (sourcePath.present) {
      map['source_path'] = Variable<String>(sourcePath.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueItemsCompanion(')
          ..write('id: $id, ')
          ..write('destinationId: $destinationId, ')
          ..write('destinationName: $destinationName, ')
          ..write('sourcePath: $sourcePath, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mimeType: $mimeType, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('progress: $progress, ')
          ..write('createdAt: $createdAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('errorCode: $errorCode, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }
}

class $UploadHistoryEntriesTable extends UploadHistoryEntries
    with TableInfo<$UploadHistoryEntriesTable, UploadHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UploadHistoryEntriesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationNameMeta = const VerificationMeta(
    'destinationName',
  );
  @override
  late final GeneratedColumn<String> destinationName = GeneratedColumn<String>(
    'destination_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationTypeMeta = const VerificationMeta(
    'destinationType',
  );
  @override
  late final GeneratedColumn<String> destinationType = GeneratedColumn<String>(
    'destination_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorTextMeta = const VerificationMeta(
    'errorText',
  );
  @override
  late final GeneratedColumn<String> errorText = GeneratedColumn<String>(
    'error_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fileName,
    destinationName,
    destinationType,
    startedAt,
    endedAt,
    durationMs,
    sizeBytes,
    status,
    errorText,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upload_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<UploadHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('destination_name')) {
      context.handle(
        _destinationNameMeta,
        destinationName.isAcceptableOrUnknown(
          data['destination_name']!,
          _destinationNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationNameMeta);
    }
    if (data.containsKey('destination_type')) {
      context.handle(
        _destinationTypeMeta,
        destinationType.isAcceptableOrUnknown(
          data['destination_type']!,
          _destinationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationTypeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_text')) {
      context.handle(
        _errorTextMeta,
        errorText.isAcceptableOrUnknown(data['error_text']!, _errorTextMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UploadHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UploadHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      destinationName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_name'],
      )!,
      destinationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_type'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_text'],
      ),
    );
  }

  @override
  $UploadHistoryEntriesTable createAlias(String alias) {
    return $UploadHistoryEntriesTable(attachedDatabase, alias);
  }
}

class UploadHistoryEntry extends DataClass
    implements Insertable<UploadHistoryEntry> {
  final int id;
  final String fileName;
  final String destinationName;
  final String destinationType;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMs;
  final int sizeBytes;
  final String status;
  final String? errorText;
  const UploadHistoryEntry({
    required this.id,
    required this.fileName,
    required this.destinationName,
    required this.destinationType,
    required this.startedAt,
    this.endedAt,
    this.durationMs,
    required this.sizeBytes,
    required this.status,
    this.errorText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['file_name'] = Variable<String>(fileName);
    map['destination_name'] = Variable<String>(destinationName);
    map['destination_type'] = Variable<String>(destinationType);
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorText != null) {
      map['error_text'] = Variable<String>(errorText);
    }
    return map;
  }

  UploadHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return UploadHistoryEntriesCompanion(
      id: Value(id),
      fileName: Value(fileName),
      destinationName: Value(destinationName),
      destinationType: Value(destinationType),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      sizeBytes: Value(sizeBytes),
      status: Value(status),
      errorText: errorText == null && nullToAbsent
          ? const Value.absent()
          : Value(errorText),
    );
  }

  factory UploadHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UploadHistoryEntry(
      id: serializer.fromJson<int>(json['id']),
      fileName: serializer.fromJson<String>(json['fileName']),
      destinationName: serializer.fromJson<String>(json['destinationName']),
      destinationType: serializer.fromJson<String>(json['destinationType']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      status: serializer.fromJson<String>(json['status']),
      errorText: serializer.fromJson<String?>(json['errorText']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fileName': serializer.toJson<String>(fileName),
      'destinationName': serializer.toJson<String>(destinationName),
      'destinationType': serializer.toJson<String>(destinationType),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'status': serializer.toJson<String>(status),
      'errorText': serializer.toJson<String?>(errorText),
    };
  }

  UploadHistoryEntry copyWith({
    int? id,
    String? fileName,
    String? destinationName,
    String? destinationType,
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    int? sizeBytes,
    String? status,
    Value<String?> errorText = const Value.absent(),
  }) => UploadHistoryEntry(
    id: id ?? this.id,
    fileName: fileName ?? this.fileName,
    destinationName: destinationName ?? this.destinationName,
    destinationType: destinationType ?? this.destinationType,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    status: status ?? this.status,
    errorText: errorText.present ? errorText.value : this.errorText,
  );
  UploadHistoryEntry copyWithCompanion(UploadHistoryEntriesCompanion data) {
    return UploadHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      destinationName: data.destinationName.present
          ? data.destinationName.value
          : this.destinationName,
      destinationType: data.destinationType.present
          ? data.destinationType.value
          : this.destinationType,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      status: data.status.present ? data.status.value : this.status,
      errorText: data.errorText.present ? data.errorText.value : this.errorText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UploadHistoryEntry(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('destinationName: $destinationName, ')
          ..write('destinationType: $destinationType, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('status: $status, ')
          ..write('errorText: $errorText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fileName,
    destinationName,
    destinationType,
    startedAt,
    endedAt,
    durationMs,
    sizeBytes,
    status,
    errorText,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadHistoryEntry &&
          other.id == this.id &&
          other.fileName == this.fileName &&
          other.destinationName == this.destinationName &&
          other.destinationType == this.destinationType &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationMs == this.durationMs &&
          other.sizeBytes == this.sizeBytes &&
          other.status == this.status &&
          other.errorText == this.errorText);
}

class UploadHistoryEntriesCompanion
    extends UpdateCompanion<UploadHistoryEntry> {
  final Value<int> id;
  final Value<String> fileName;
  final Value<String> destinationName;
  final Value<String> destinationType;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> durationMs;
  final Value<int> sizeBytes;
  final Value<String> status;
  final Value<String?> errorText;
  const UploadHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.fileName = const Value.absent(),
    this.destinationName = const Value.absent(),
    this.destinationType = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.errorText = const Value.absent(),
  });
  UploadHistoryEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String fileName,
    required String destinationName,
    required String destinationType,
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    required int sizeBytes,
    required String status,
    this.errorText = const Value.absent(),
  }) : fileName = Value(fileName),
       destinationName = Value(destinationName),
       destinationType = Value(destinationType),
       startedAt = Value(startedAt),
       sizeBytes = Value(sizeBytes),
       status = Value(status);
  static Insertable<UploadHistoryEntry> custom({
    Expression<int>? id,
    Expression<String>? fileName,
    Expression<String>? destinationName,
    Expression<String>? destinationType,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationMs,
    Expression<int>? sizeBytes,
    Expression<String>? status,
    Expression<String>? errorText,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fileName != null) 'file_name': fileName,
      if (destinationName != null) 'destination_name': destinationName,
      if (destinationType != null) 'destination_type': destinationType,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (status != null) 'status': status,
      if (errorText != null) 'error_text': errorText,
    });
  }

  UploadHistoryEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? fileName,
    Value<String>? destinationName,
    Value<String>? destinationType,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int?>? durationMs,
    Value<int>? sizeBytes,
    Value<String>? status,
    Value<String?>? errorText,
  }) {
    return UploadHistoryEntriesCompanion(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      destinationName: destinationName ?? this.destinationName,
      destinationType: destinationType ?? this.destinationType,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      status: status ?? this.status,
      errorText: errorText ?? this.errorText,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (destinationName.present) {
      map['destination_name'] = Variable<String>(destinationName.value);
    }
    if (destinationType.present) {
      map['destination_type'] = Variable<String>(destinationType.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorText.present) {
      map['error_text'] = Variable<String>(errorText.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UploadHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('fileName: $fileName, ')
          ..write('destinationName: $destinationName, ')
          ..write('destinationType: $destinationType, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('status: $status, ')
          ..write('errorText: $errorText')
          ..write(')'))
        .toString();
  }
}

class $MediaDestinationsTable extends MediaDestinations
    with TableInfo<$MediaDestinationsTable, MediaDestination> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaDestinationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _secretKeyMeta = const VerificationMeta(
    'secretKey',
  );
  @override
  late final GeneratedColumn<String> secretKey = GeneratedColumn<String>(
    'secret_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _guildIdMeta = const VerificationMeta(
    'guildId',
  );
  @override
  late final GeneratedColumn<String> guildId = GeneratedColumn<String>(
    'guild_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelIdMeta = const VerificationMeta(
    'channelId',
  );
  @override
  late final GeneratedColumn<String> channelId = GeneratedColumn<String>(
    'channel_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _activeMeta = const VerificationMeta('active');
  @override
  late final GeneratedColumn<bool> active = GeneratedColumn<bool>(
    'active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("active" IN (0, 1))',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    secretKey,
    guildId,
    channelId,
    active,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_destinations';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaDestination> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('secret_key')) {
      context.handle(
        _secretKeyMeta,
        secretKey.isAcceptableOrUnknown(data['secret_key']!, _secretKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_secretKeyMeta);
    }
    if (data.containsKey('guild_id')) {
      context.handle(
        _guildIdMeta,
        guildId.isAcceptableOrUnknown(data['guild_id']!, _guildIdMeta),
      );
    }
    if (data.containsKey('channel_id')) {
      context.handle(
        _channelIdMeta,
        channelId.isAcceptableOrUnknown(data['channel_id']!, _channelIdMeta),
      );
    }
    if (data.containsKey('active')) {
      context.handle(
        _activeMeta,
        active.isAcceptableOrUnknown(data['active']!, _activeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MediaDestination map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaDestination(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      secretKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}secret_key'],
      )!,
      guildId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guild_id'],
      ),
      channelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}channel_id'],
      ),
      active: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MediaDestinationsTable createAlias(String alias) {
    return $MediaDestinationsTable(attachedDatabase, alias);
  }
}

class MediaDestination extends DataClass
    implements Insertable<MediaDestination> {
  final String id;
  final String name;
  final String type;
  final String secretKey;
  final String? guildId;
  final String? channelId;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  const MediaDestination({
    required this.id,
    required this.name,
    required this.type,
    required this.secretKey,
    this.guildId,
    this.channelId,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['secret_key'] = Variable<String>(secretKey);
    if (!nullToAbsent || guildId != null) {
      map['guild_id'] = Variable<String>(guildId);
    }
    if (!nullToAbsent || channelId != null) {
      map['channel_id'] = Variable<String>(channelId);
    }
    map['active'] = Variable<bool>(active);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaDestinationsCompanion toCompanion(bool nullToAbsent) {
    return MediaDestinationsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      secretKey: Value(secretKey),
      guildId: guildId == null && nullToAbsent
          ? const Value.absent()
          : Value(guildId),
      channelId: channelId == null && nullToAbsent
          ? const Value.absent()
          : Value(channelId),
      active: Value(active),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaDestination.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaDestination(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      secretKey: serializer.fromJson<String>(json['secretKey']),
      guildId: serializer.fromJson<String?>(json['guildId']),
      channelId: serializer.fromJson<String?>(json['channelId']),
      active: serializer.fromJson<bool>(json['active']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'secretKey': serializer.toJson<String>(secretKey),
      'guildId': serializer.toJson<String?>(guildId),
      'channelId': serializer.toJson<String?>(channelId),
      'active': serializer.toJson<bool>(active),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaDestination copyWith({
    String? id,
    String? name,
    String? type,
    String? secretKey,
    Value<String?> guildId = const Value.absent(),
    Value<String?> channelId = const Value.absent(),
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => MediaDestination(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    secretKey: secretKey ?? this.secretKey,
    guildId: guildId.present ? guildId.value : this.guildId,
    channelId: channelId.present ? channelId.value : this.channelId,
    active: active ?? this.active,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MediaDestination copyWithCompanion(MediaDestinationsCompanion data) {
    return MediaDestination(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      secretKey: data.secretKey.present ? data.secretKey.value : this.secretKey,
      guildId: data.guildId.present ? data.guildId.value : this.guildId,
      channelId: data.channelId.present ? data.channelId.value : this.channelId,
      active: data.active.present ? data.active.value : this.active,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaDestination(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('secretKey: $secretKey, ')
          ..write('guildId: $guildId, ')
          ..write('channelId: $channelId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    secretKey,
    guildId,
    channelId,
    active,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaDestination &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.secretKey == this.secretKey &&
          other.guildId == this.guildId &&
          other.channelId == this.channelId &&
          other.active == this.active &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class MediaDestinationsCompanion extends UpdateCompanion<MediaDestination> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> secretKey;
  final Value<String?> guildId;
  final Value<String?> channelId;
  final Value<bool> active;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MediaDestinationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.secretKey = const Value.absent(),
    this.guildId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.active = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaDestinationsCompanion.insert({
    required String id,
    required String name,
    required String type,
    required String secretKey,
    this.guildId = const Value.absent(),
    this.channelId = const Value.absent(),
    this.active = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       secretKey = Value(secretKey),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<MediaDestination> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? secretKey,
    Expression<String>? guildId,
    Expression<String>? channelId,
    Expression<bool>? active,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (secretKey != null) 'secret_key': secretKey,
      if (guildId != null) 'guild_id': guildId,
      if (channelId != null) 'channel_id': channelId,
      if (active != null) 'active': active,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaDestinationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? secretKey,
    Value<String?>? guildId,
    Value<String?>? channelId,
    Value<bool>? active,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MediaDestinationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      secretKey: secretKey ?? this.secretKey,
      guildId: guildId ?? this.guildId,
      channelId: channelId ?? this.channelId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (secretKey.present) {
      map['secret_key'] = Variable<String>(secretKey.value);
    }
    if (guildId.present) {
      map['guild_id'] = Variable<String>(guildId.value);
    }
    if (channelId.present) {
      map['channel_id'] = Variable<String>(channelId.value);
    }
    if (active.present) {
      map['active'] = Variable<bool>(active.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MediaDestinationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('secretKey: $secretKey, ')
          ..write('guildId: $guildId, ')
          ..write('channelId: $channelId, ')
          ..write('active: $active, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingEntriesTable extends SettingEntries
    with TableInfo<$SettingEntriesTable, SettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingEntriesTable createAlias(String alias) {
    return $SettingEntriesTable(attachedDatabase, alias);
  }
}

class SettingEntry extends DataClass implements Insertable<SettingEntry> {
  final String key;
  final String value;
  const SettingEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingEntry copyWith({String? key, String? value}) =>
      SettingEntry(key: key ?? this.key, value: value ?? this.value);
  SettingEntry copyWithCompanion(SettingEntriesCompanion data) {
    return SettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingEntriesCompanion extends UpdateCompanion<SettingEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteGuildsTable extends FavoriteGuilds
    with TableInfo<$FavoriteGuildsTable, FavoriteGuild> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteGuildsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _guildIdMeta = const VerificationMeta(
    'guildId',
  );
  @override
  late final GeneratedColumn<String> guildId = GeneratedColumn<String>(
    'guild_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pinnedAtMeta = const VerificationMeta(
    'pinnedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pinnedAt = GeneratedColumn<DateTime>(
    'pinned_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [guildId, pinnedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_guilds';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteGuild> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('guild_id')) {
      context.handle(
        _guildIdMeta,
        guildId.isAcceptableOrUnknown(data['guild_id']!, _guildIdMeta),
      );
    } else if (isInserting) {
      context.missing(_guildIdMeta);
    }
    if (data.containsKey('pinned_at')) {
      context.handle(
        _pinnedAtMeta,
        pinnedAt.isAcceptableOrUnknown(data['pinned_at']!, _pinnedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pinnedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {guildId};
  @override
  FavoriteGuild map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteGuild(
      guildId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guild_id'],
      )!,
      pinnedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}pinned_at'],
      )!,
    );
  }

  @override
  $FavoriteGuildsTable createAlias(String alias) {
    return $FavoriteGuildsTable(attachedDatabase, alias);
  }
}

class FavoriteGuild extends DataClass implements Insertable<FavoriteGuild> {
  final String guildId;
  final DateTime pinnedAt;
  const FavoriteGuild({required this.guildId, required this.pinnedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['guild_id'] = Variable<String>(guildId);
    map['pinned_at'] = Variable<DateTime>(pinnedAt);
    return map;
  }

  FavoriteGuildsCompanion toCompanion(bool nullToAbsent) {
    return FavoriteGuildsCompanion(
      guildId: Value(guildId),
      pinnedAt: Value(pinnedAt),
    );
  }

  factory FavoriteGuild.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteGuild(
      guildId: serializer.fromJson<String>(json['guildId']),
      pinnedAt: serializer.fromJson<DateTime>(json['pinnedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'guildId': serializer.toJson<String>(guildId),
      'pinnedAt': serializer.toJson<DateTime>(pinnedAt),
    };
  }

  FavoriteGuild copyWith({String? guildId, DateTime? pinnedAt}) =>
      FavoriteGuild(
        guildId: guildId ?? this.guildId,
        pinnedAt: pinnedAt ?? this.pinnedAt,
      );
  FavoriteGuild copyWithCompanion(FavoriteGuildsCompanion data) {
    return FavoriteGuild(
      guildId: data.guildId.present ? data.guildId.value : this.guildId,
      pinnedAt: data.pinnedAt.present ? data.pinnedAt.value : this.pinnedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteGuild(')
          ..write('guildId: $guildId, ')
          ..write('pinnedAt: $pinnedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(guildId, pinnedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteGuild &&
          other.guildId == this.guildId &&
          other.pinnedAt == this.pinnedAt);
}

class FavoriteGuildsCompanion extends UpdateCompanion<FavoriteGuild> {
  final Value<String> guildId;
  final Value<DateTime> pinnedAt;
  final Value<int> rowid;
  const FavoriteGuildsCompanion({
    this.guildId = const Value.absent(),
    this.pinnedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteGuildsCompanion.insert({
    required String guildId,
    required DateTime pinnedAt,
    this.rowid = const Value.absent(),
  }) : guildId = Value(guildId),
       pinnedAt = Value(pinnedAt);
  static Insertable<FavoriteGuild> custom({
    Expression<String>? guildId,
    Expression<DateTime>? pinnedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (guildId != null) 'guild_id': guildId,
      if (pinnedAt != null) 'pinned_at': pinnedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteGuildsCompanion copyWith({
    Value<String>? guildId,
    Value<DateTime>? pinnedAt,
    Value<int>? rowid,
  }) {
    return FavoriteGuildsCompanion(
      guildId: guildId ?? this.guildId,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (guildId.present) {
      map['guild_id'] = Variable<String>(guildId.value);
    }
    if (pinnedAt.present) {
      map['pinned_at'] = Variable<DateTime>(pinnedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteGuildsCompanion(')
          ..write('guildId: $guildId, ')
          ..write('pinnedAt: $pinnedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UploadQueueItemsTable uploadQueueItems = $UploadQueueItemsTable(
    this,
  );
  late final $UploadHistoryEntriesTable uploadHistoryEntries =
      $UploadHistoryEntriesTable(this);
  late final $MediaDestinationsTable mediaDestinations =
      $MediaDestinationsTable(this);
  late final $SettingEntriesTable settingEntries = $SettingEntriesTable(this);
  late final $FavoriteGuildsTable favoriteGuilds = $FavoriteGuildsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    uploadQueueItems,
    uploadHistoryEntries,
    mediaDestinations,
    settingEntries,
    favoriteGuilds,
  ];
}

typedef $$UploadQueueItemsTableCreateCompanionBuilder =
    UploadQueueItemsCompanion Function({
      Value<int> id,
      required String destinationId,
      required String destinationName,
      required String sourcePath,
      required String fileName,
      required int sizeBytes,
      Value<String?> mimeType,
      required String kind,
      required String state,
      Value<double> progress,
      required DateTime createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> position,
    });
typedef $$UploadQueueItemsTableUpdateCompanionBuilder =
    UploadQueueItemsCompanion Function({
      Value<int> id,
      Value<String> destinationId,
      Value<String> destinationName,
      Value<String> sourcePath,
      Value<String> fileName,
      Value<int> sizeBytes,
      Value<String?> mimeType,
      Value<String> kind,
      Value<String> state,
      Value<double> progress,
      Value<DateTime> createdAt,
      Value<DateTime?> startedAt,
      Value<DateTime?> finishedAt,
      Value<String?> errorCode,
      Value<String?> errorMessage,
      Value<int> position,
    });

class $$UploadQueueItemsTableFilterComposer
    extends Composer<_$AppDatabase, $UploadQueueItemsTable> {
  $$UploadQueueItemsTableFilterComposer({
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

  ColumnFilters<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UploadQueueItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $UploadQueueItemsTable> {
  $$UploadQueueItemsTableOrderingComposer({
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

  ColumnOrderings<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get progress => $composableBuilder(
    column: $table.progress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UploadQueueItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UploadQueueItemsTable> {
  $$UploadQueueItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePath => $composableBuilder(
    column: $table.sourcePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt => $composableBuilder(
    column: $table.finishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$UploadQueueItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UploadQueueItemsTable,
          UploadQueueItem,
          $$UploadQueueItemsTableFilterComposer,
          $$UploadQueueItemsTableOrderingComposer,
          $$UploadQueueItemsTableAnnotationComposer,
          $$UploadQueueItemsTableCreateCompanionBuilder,
          $$UploadQueueItemsTableUpdateCompanionBuilder,
          (
            UploadQueueItem,
            BaseReferences<
              _$AppDatabase,
              $UploadQueueItemsTable,
              UploadQueueItem
            >,
          ),
          UploadQueueItem,
          PrefetchHooks Function()
        > {
  $$UploadQueueItemsTableTableManager(
    _$AppDatabase db,
    $UploadQueueItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UploadQueueItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UploadQueueItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UploadQueueItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> destinationId = const Value.absent(),
                Value<String> destinationName = const Value.absent(),
                Value<String> sourcePath = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => UploadQueueItemsCompanion(
                id: id,
                destinationId: destinationId,
                destinationName: destinationName,
                sourcePath: sourcePath,
                fileName: fileName,
                sizeBytes: sizeBytes,
                mimeType: mimeType,
                kind: kind,
                state: state,
                progress: progress,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorCode: errorCode,
                errorMessage: errorMessage,
                position: position,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String destinationId,
                required String destinationName,
                required String sourcePath,
                required String fileName,
                required int sizeBytes,
                Value<String?> mimeType = const Value.absent(),
                required String kind,
                required String state,
                Value<double> progress = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> startedAt = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> position = const Value.absent(),
              }) => UploadQueueItemsCompanion.insert(
                id: id,
                destinationId: destinationId,
                destinationName: destinationName,
                sourcePath: sourcePath,
                fileName: fileName,
                sizeBytes: sizeBytes,
                mimeType: mimeType,
                kind: kind,
                state: state,
                progress: progress,
                createdAt: createdAt,
                startedAt: startedAt,
                finishedAt: finishedAt,
                errorCode: errorCode,
                errorMessage: errorMessage,
                position: position,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UploadQueueItemsTable, UploadQueueItem>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UploadQueueItemsTable,
                    UploadQueueItem
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UploadQueueItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UploadQueueItemsTable,
      UploadQueueItem,
      $$UploadQueueItemsTableFilterComposer,
      $$UploadQueueItemsTableOrderingComposer,
      $$UploadQueueItemsTableAnnotationComposer,
      $$UploadQueueItemsTableCreateCompanionBuilder,
      $$UploadQueueItemsTableUpdateCompanionBuilder,
      (
        UploadQueueItem,
        BaseReferences<_$AppDatabase, $UploadQueueItemsTable, UploadQueueItem>,
      ),
      UploadQueueItem,
      PrefetchHooks Function()
    >;
typedef $$UploadHistoryEntriesTableCreateCompanionBuilder =
    UploadHistoryEntriesCompanion Function({
      Value<int> id,
      required String fileName,
      required String destinationName,
      required String destinationType,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int?> durationMs,
      required int sizeBytes,
      required String status,
      Value<String?> errorText,
    });
typedef $$UploadHistoryEntriesTableUpdateCompanionBuilder =
    UploadHistoryEntriesCompanion Function({
      Value<int> id,
      Value<String> fileName,
      Value<String> destinationName,
      Value<String> destinationType,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int?> durationMs,
      Value<int> sizeBytes,
      Value<String> status,
      Value<String?> errorText,
    });

class $$UploadHistoryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $UploadHistoryEntriesTable> {
  $$UploadHistoryEntriesTableFilterComposer({
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

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationType => $composableBuilder(
    column: $table.destinationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UploadHistoryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $UploadHistoryEntriesTable> {
  $$UploadHistoryEntriesTableOrderingComposer({
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

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationType => $composableBuilder(
    column: $table.destinationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorText => $composableBuilder(
    column: $table.errorText,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UploadHistoryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UploadHistoryEntriesTable> {
  $$UploadHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<String> get destinationName => $composableBuilder(
    column: $table.destinationName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationType => $composableBuilder(
    column: $table.destinationType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorText =>
      $composableBuilder(column: $table.errorText, builder: (column) => column);
}

class $$UploadHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UploadHistoryEntriesTable,
          UploadHistoryEntry,
          $$UploadHistoryEntriesTableFilterComposer,
          $$UploadHistoryEntriesTableOrderingComposer,
          $$UploadHistoryEntriesTableAnnotationComposer,
          $$UploadHistoryEntriesTableCreateCompanionBuilder,
          $$UploadHistoryEntriesTableUpdateCompanionBuilder,
          (
            UploadHistoryEntry,
            BaseReferences<
              _$AppDatabase,
              $UploadHistoryEntriesTable,
              UploadHistoryEntry
            >,
          ),
          UploadHistoryEntry,
          PrefetchHooks Function()
        > {
  $$UploadHistoryEntriesTableTableManager(
    _$AppDatabase db,
    $UploadHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UploadHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UploadHistoryEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UploadHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<String> destinationName = const Value.absent(),
                Value<String> destinationType = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorText = const Value.absent(),
              }) => UploadHistoryEntriesCompanion(
                id: id,
                fileName: fileName,
                destinationName: destinationName,
                destinationType: destinationType,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                status: status,
                errorText: errorText,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fileName,
                required String destinationName,
                required String destinationType,
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required int sizeBytes,
                required String status,
                Value<String?> errorText = const Value.absent(),
              }) => UploadHistoryEntriesCompanion.insert(
                id: id,
                fileName: fileName,
                destinationName: destinationName,
                destinationType: destinationType,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMs: durationMs,
                sizeBytes: sizeBytes,
                status: status,
                errorText: errorText,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UploadHistoryEntriesTable, UploadHistoryEntry>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $UploadHistoryEntriesTable,
                    UploadHistoryEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UploadHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UploadHistoryEntriesTable,
      UploadHistoryEntry,
      $$UploadHistoryEntriesTableFilterComposer,
      $$UploadHistoryEntriesTableOrderingComposer,
      $$UploadHistoryEntriesTableAnnotationComposer,
      $$UploadHistoryEntriesTableCreateCompanionBuilder,
      $$UploadHistoryEntriesTableUpdateCompanionBuilder,
      (
        UploadHistoryEntry,
        BaseReferences<
          _$AppDatabase,
          $UploadHistoryEntriesTable,
          UploadHistoryEntry
        >,
      ),
      UploadHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$MediaDestinationsTableCreateCompanionBuilder =
    MediaDestinationsCompanion Function({
      required String id,
      required String name,
      required String type,
      required String secretKey,
      Value<String?> guildId,
      Value<String?> channelId,
      Value<bool> active,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MediaDestinationsTableUpdateCompanionBuilder =
    MediaDestinationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String> secretKey,
      Value<String?> guildId,
      Value<String?> channelId,
      Value<bool> active,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MediaDestinationsTableFilterComposer
    extends Composer<_$AppDatabase, $MediaDestinationsTable> {
  $$MediaDestinationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get secretKey => $composableBuilder(
    column: $table.secretKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guildId => $composableBuilder(
    column: $table.guildId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaDestinationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MediaDestinationsTable> {
  $$MediaDestinationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get secretKey => $composableBuilder(
    column: $table.secretKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guildId => $composableBuilder(
    column: $table.guildId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get channelId => $composableBuilder(
    column: $table.channelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get active => $composableBuilder(
    column: $table.active,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaDestinationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MediaDestinationsTable> {
  $$MediaDestinationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get secretKey =>
      $composableBuilder(column: $table.secretKey, builder: (column) => column);

  GeneratedColumn<String> get guildId =>
      $composableBuilder(column: $table.guildId, builder: (column) => column);

  GeneratedColumn<String> get channelId =>
      $composableBuilder(column: $table.channelId, builder: (column) => column);

  GeneratedColumn<bool> get active =>
      $composableBuilder(column: $table.active, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaDestinationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MediaDestinationsTable,
          MediaDestination,
          $$MediaDestinationsTableFilterComposer,
          $$MediaDestinationsTableOrderingComposer,
          $$MediaDestinationsTableAnnotationComposer,
          $$MediaDestinationsTableCreateCompanionBuilder,
          $$MediaDestinationsTableUpdateCompanionBuilder,
          (
            MediaDestination,
            BaseReferences<
              _$AppDatabase,
              $MediaDestinationsTable,
              MediaDestination
            >,
          ),
          MediaDestination,
          PrefetchHooks Function()
        > {
  $$MediaDestinationsTableTableManager(
    _$AppDatabase db,
    $MediaDestinationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaDestinationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaDestinationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaDestinationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> secretKey = const Value.absent(),
                Value<String?> guildId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaDestinationsCompanion(
                id: id,
                name: name,
                type: type,
                secretKey: secretKey,
                guildId: guildId,
                channelId: channelId,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                required String secretKey,
                Value<String?> guildId = const Value.absent(),
                Value<String?> channelId = const Value.absent(),
                Value<bool> active = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaDestinationsCompanion.insert(
                id: id,
                name: name,
                type: type,
                secretKey: secretKey,
                guildId: guildId,
                channelId: channelId,
                active: active,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MediaDestinationsTable, MediaDestination>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $MediaDestinationsTable,
                    MediaDestination
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaDestinationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MediaDestinationsTable,
      MediaDestination,
      $$MediaDestinationsTableFilterComposer,
      $$MediaDestinationsTableOrderingComposer,
      $$MediaDestinationsTableAnnotationComposer,
      $$MediaDestinationsTableCreateCompanionBuilder,
      $$MediaDestinationsTableUpdateCompanionBuilder,
      (
        MediaDestination,
        BaseReferences<
          _$AppDatabase,
          $MediaDestinationsTable,
          MediaDestination
        >,
      ),
      MediaDestination,
      PrefetchHooks Function()
    >;
typedef $$SettingEntriesTableCreateCompanionBuilder =
    SettingEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingEntriesTableUpdateCompanionBuilder =
    SettingEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingEntriesTable,
          SettingEntry,
          $$SettingEntriesTableFilterComposer,
          $$SettingEntriesTableOrderingComposer,
          $$SettingEntriesTableAnnotationComposer,
          $$SettingEntriesTableCreateCompanionBuilder,
          $$SettingEntriesTableUpdateCompanionBuilder,
          (
            SettingEntry,
            BaseReferences<_$AppDatabase, $SettingEntriesTable, SettingEntry>,
          ),
          SettingEntry,
          PrefetchHooks Function()
        > {
  $$SettingEntriesTableTableManager(
    _$AppDatabase db,
    $SettingEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingEntriesTable, SettingEntry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SettingEntriesTable,
                    SettingEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingEntriesTable,
      SettingEntry,
      $$SettingEntriesTableFilterComposer,
      $$SettingEntriesTableOrderingComposer,
      $$SettingEntriesTableAnnotationComposer,
      $$SettingEntriesTableCreateCompanionBuilder,
      $$SettingEntriesTableUpdateCompanionBuilder,
      (
        SettingEntry,
        BaseReferences<_$AppDatabase, $SettingEntriesTable, SettingEntry>,
      ),
      SettingEntry,
      PrefetchHooks Function()
    >;
typedef $$FavoriteGuildsTableCreateCompanionBuilder =
    FavoriteGuildsCompanion Function({
      required String guildId,
      required DateTime pinnedAt,
      Value<int> rowid,
    });
typedef $$FavoriteGuildsTableUpdateCompanionBuilder =
    FavoriteGuildsCompanion Function({
      Value<String> guildId,
      Value<DateTime> pinnedAt,
      Value<int> rowid,
    });

class $$FavoriteGuildsTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteGuildsTable> {
  $$FavoriteGuildsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get guildId => $composableBuilder(
    column: $table.guildId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavoriteGuildsTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteGuildsTable> {
  $$FavoriteGuildsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get guildId => $composableBuilder(
    column: $table.guildId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pinnedAt => $composableBuilder(
    column: $table.pinnedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteGuildsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteGuildsTable> {
  $$FavoriteGuildsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get guildId =>
      $composableBuilder(column: $table.guildId, builder: (column) => column);

  GeneratedColumn<DateTime> get pinnedAt =>
      $composableBuilder(column: $table.pinnedAt, builder: (column) => column);
}

class $$FavoriteGuildsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteGuildsTable,
          FavoriteGuild,
          $$FavoriteGuildsTableFilterComposer,
          $$FavoriteGuildsTableOrderingComposer,
          $$FavoriteGuildsTableAnnotationComposer,
          $$FavoriteGuildsTableCreateCompanionBuilder,
          $$FavoriteGuildsTableUpdateCompanionBuilder,
          (
            FavoriteGuild,
            BaseReferences<_$AppDatabase, $FavoriteGuildsTable, FavoriteGuild>,
          ),
          FavoriteGuild,
          PrefetchHooks Function()
        > {
  $$FavoriteGuildsTableTableManager(
    _$AppDatabase db,
    $FavoriteGuildsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteGuildsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteGuildsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoriteGuildsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> guildId = const Value.absent(),
                Value<DateTime> pinnedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteGuildsCompanion(
                guildId: guildId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String guildId,
                required DateTime pinnedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteGuildsCompanion.insert(
                guildId: guildId,
                pinnedAt: pinnedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FavoriteGuildsTable, FavoriteGuild>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $FavoriteGuildsTable,
                    FavoriteGuild
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavoriteGuildsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteGuildsTable,
      FavoriteGuild,
      $$FavoriteGuildsTableFilterComposer,
      $$FavoriteGuildsTableOrderingComposer,
      $$FavoriteGuildsTableAnnotationComposer,
      $$FavoriteGuildsTableCreateCompanionBuilder,
      $$FavoriteGuildsTableUpdateCompanionBuilder,
      (
        FavoriteGuild,
        BaseReferences<_$AppDatabase, $FavoriteGuildsTable, FavoriteGuild>,
      ),
      FavoriteGuild,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UploadQueueItemsTableTableManager get uploadQueueItems =>
      $$UploadQueueItemsTableTableManager(_db, _db.uploadQueueItems);
  $$UploadHistoryEntriesTableTableManager get uploadHistoryEntries =>
      $$UploadHistoryEntriesTableTableManager(_db, _db.uploadHistoryEntries);
  $$MediaDestinationsTableTableManager get mediaDestinations =>
      $$MediaDestinationsTableTableManager(_db, _db.mediaDestinations);
  $$SettingEntriesTableTableManager get settingEntries =>
      $$SettingEntriesTableTableManager(_db, _db.settingEntries);
  $$FavoriteGuildsTableTableManager get favoriteGuilds =>
      $$FavoriteGuildsTableTableManager(_db, _db.favoriteGuilds);
}
