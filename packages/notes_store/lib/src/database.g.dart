// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverMeta = const VerificationMeta('server');
  @override
  late final GeneratedColumn<String> server = GeneratedColumn<String>(
    'server',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _loginNameMeta = const VerificationMeta(
    'loginName',
  );
  @override
  late final GeneratedColumn<String> loginName = GeneratedColumn<String>(
    'login_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _credentialRefMeta = const VerificationMeta(
    'credentialRef',
  );
  @override
  late final GeneratedColumn<String> credentialRef = GeneratedColumn<String>(
    'credential_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('capabilitiesPending'),
  );
  static const VerificationMeta _generationMeta = const VerificationMeta(
    'generation',
  );
  @override
  late final GeneratedColumn<int> generation = GeneratedColumn<int>(
    'generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _mutationEpochMeta = const VerificationMeta(
    'mutationEpoch',
  );
  @override
  late final GeneratedColumn<int> mutationEpoch = GeneratedColumn<int>(
    'mutation_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    server,
    loginName,
    credentialRef,
    state,
    generation,
    mutationEpoch,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server')) {
      context.handle(
        _serverMeta,
        server.isAcceptableOrUnknown(data['server']!, _serverMeta),
      );
    } else if (isInserting) {
      context.missing(_serverMeta);
    }
    if (data.containsKey('login_name')) {
      context.handle(
        _loginNameMeta,
        loginName.isAcceptableOrUnknown(data['login_name']!, _loginNameMeta),
      );
    } else if (isInserting) {
      context.missing(_loginNameMeta);
    }
    if (data.containsKey('credential_ref')) {
      context.handle(
        _credentialRefMeta,
        credentialRef.isAcceptableOrUnknown(
          data['credential_ref']!,
          _credentialRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_credentialRefMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('generation')) {
      context.handle(
        _generationMeta,
        generation.isAcceptableOrUnknown(data['generation']!, _generationMeta),
      );
    }
    if (data.containsKey('mutation_epoch')) {
      context.handle(
        _mutationEpochMeta,
        mutationEpoch.isAcceptableOrUnknown(
          data['mutation_epoch']!,
          _mutationEpochMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      server: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server'],
      )!,
      loginName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}login_name'],
      )!,
      credentialRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_ref'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      generation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generation'],
      )!,
      mutationEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mutation_epoch'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String server;
  final String loginName;
  final String credentialRef;
  final String state;
  final int generation;
  final int mutationEpoch;
  const Account({
    required this.id,
    required this.server,
    required this.loginName,
    required this.credentialRef,
    required this.state,
    required this.generation,
    required this.mutationEpoch,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['server'] = Variable<String>(server);
    map['login_name'] = Variable<String>(loginName);
    map['credential_ref'] = Variable<String>(credentialRef);
    map['state'] = Variable<String>(state);
    map['generation'] = Variable<int>(generation);
    map['mutation_epoch'] = Variable<int>(mutationEpoch);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      server: Value(server),
      loginName: Value(loginName),
      credentialRef: Value(credentialRef),
      state: Value(state),
      generation: Value(generation),
      mutationEpoch: Value(mutationEpoch),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      server: serializer.fromJson<String>(json['server']),
      loginName: serializer.fromJson<String>(json['loginName']),
      credentialRef: serializer.fromJson<String>(json['credentialRef']),
      state: serializer.fromJson<String>(json['state']),
      generation: serializer.fromJson<int>(json['generation']),
      mutationEpoch: serializer.fromJson<int>(json['mutationEpoch']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'server': serializer.toJson<String>(server),
      'loginName': serializer.toJson<String>(loginName),
      'credentialRef': serializer.toJson<String>(credentialRef),
      'state': serializer.toJson<String>(state),
      'generation': serializer.toJson<int>(generation),
      'mutationEpoch': serializer.toJson<int>(mutationEpoch),
    };
  }

  Account copyWith({
    String? id,
    String? server,
    String? loginName,
    String? credentialRef,
    String? state,
    int? generation,
    int? mutationEpoch,
  }) => Account(
    id: id ?? this.id,
    server: server ?? this.server,
    loginName: loginName ?? this.loginName,
    credentialRef: credentialRef ?? this.credentialRef,
    state: state ?? this.state,
    generation: generation ?? this.generation,
    mutationEpoch: mutationEpoch ?? this.mutationEpoch,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      server: data.server.present ? data.server.value : this.server,
      loginName: data.loginName.present ? data.loginName.value : this.loginName,
      credentialRef: data.credentialRef.present
          ? data.credentialRef.value
          : this.credentialRef,
      state: data.state.present ? data.state.value : this.state,
      generation: data.generation.present
          ? data.generation.value
          : this.generation,
      mutationEpoch: data.mutationEpoch.present
          ? data.mutationEpoch.value
          : this.mutationEpoch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('server: $server, ')
          ..write('loginName: $loginName, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('state: $state, ')
          ..write('generation: $generation, ')
          ..write('mutationEpoch: $mutationEpoch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    server,
    loginName,
    credentialRef,
    state,
    generation,
    mutationEpoch,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.server == this.server &&
          other.loginName == this.loginName &&
          other.credentialRef == this.credentialRef &&
          other.state == this.state &&
          other.generation == this.generation &&
          other.mutationEpoch == this.mutationEpoch);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> server;
  final Value<String> loginName;
  final Value<String> credentialRef;
  final Value<String> state;
  final Value<int> generation;
  final Value<int> mutationEpoch;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.server = const Value.absent(),
    this.loginName = const Value.absent(),
    this.credentialRef = const Value.absent(),
    this.state = const Value.absent(),
    this.generation = const Value.absent(),
    this.mutationEpoch = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String server,
    required String loginName,
    required String credentialRef,
    this.state = const Value.absent(),
    this.generation = const Value.absent(),
    this.mutationEpoch = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       server = Value(server),
       loginName = Value(loginName),
       credentialRef = Value(credentialRef);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? server,
    Expression<String>? loginName,
    Expression<String>? credentialRef,
    Expression<String>? state,
    Expression<int>? generation,
    Expression<int>? mutationEpoch,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (server != null) 'server': server,
      if (loginName != null) 'login_name': loginName,
      if (credentialRef != null) 'credential_ref': credentialRef,
      if (state != null) 'state': state,
      if (generation != null) 'generation': generation,
      if (mutationEpoch != null) 'mutation_epoch': mutationEpoch,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? server,
    Value<String>? loginName,
    Value<String>? credentialRef,
    Value<String>? state,
    Value<int>? generation,
    Value<int>? mutationEpoch,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      server: server ?? this.server,
      loginName: loginName ?? this.loginName,
      credentialRef: credentialRef ?? this.credentialRef,
      state: state ?? this.state,
      generation: generation ?? this.generation,
      mutationEpoch: mutationEpoch ?? this.mutationEpoch,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (server.present) {
      map['server'] = Variable<String>(server.value);
    }
    if (loginName.present) {
      map['login_name'] = Variable<String>(loginName.value);
    }
    if (credentialRef.present) {
      map['credential_ref'] = Variable<String>(credentialRef.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (generation.present) {
      map['generation'] = Variable<int>(generation.value);
    }
    if (mutationEpoch.present) {
      map['mutation_epoch'] = Variable<int>(mutationEpoch.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('server: $server, ')
          ..write('loginName: $loginName, ')
          ..write('credentialRef: $credentialRef, ')
          ..write('state: $state, ')
          ..write('generation: $generation, ')
          ..write('mutationEpoch: $mutationEpoch, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalNotesTable extends LocalNotes
    with TableInfo<$LocalNotesTable, LocalNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<int> remoteId = GeneratedColumn<int>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _favoriteMeta = const VerificationMeta(
    'favorite',
  );
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
    'favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _readonlyMeta = const VerificationMeta(
    'readonly',
  );
  @override
  late final GeneratedColumn<bool> readonly = GeneratedColumn<bool>(
    'readonly',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("readonly" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseContentMeta = const VerificationMeta(
    'baseContent',
  );
  @override
  late final GeneratedColumn<String> baseContent = GeneratedColumn<String>(
    'base_content',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseTitleMeta = const VerificationMeta(
    'baseTitle',
  );
  @override
  late final GeneratedColumn<String> baseTitle = GeneratedColumn<String>(
    'base_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseCategoryMeta = const VerificationMeta(
    'baseCategory',
  );
  @override
  late final GeneratedColumn<String> baseCategory = GeneratedColumn<String>(
    'base_category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _baseFavoriteMeta = const VerificationMeta(
    'baseFavorite',
  );
  @override
  late final GeneratedColumn<bool> baseFavorite = GeneratedColumn<bool>(
    'base_favorite',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("base_favorite" IN (0, 1))',
    ),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('draft'),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('note'),
  );
  static const VerificationMeta _davPathMeta = const VerificationMeta(
    'davPath',
  );
  @override
  late final GeneratedColumn<String> davPath = GeneratedColumn<String>(
    'dav_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    remoteId,
    title,
    content,
    category,
    favorite,
    readonly,
    revision,
    etag,
    baseContent,
    baseTitle,
    baseCategory,
    baseFavorite,
    syncState,
    updatedAt,
    kind,
    davPath,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('favorite')) {
      context.handle(
        _favoriteMeta,
        favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta),
      );
    }
    if (data.containsKey('readonly')) {
      context.handle(
        _readonlyMeta,
        readonly.isAcceptableOrUnknown(data['readonly']!, _readonlyMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('base_content')) {
      context.handle(
        _baseContentMeta,
        baseContent.isAcceptableOrUnknown(
          data['base_content']!,
          _baseContentMeta,
        ),
      );
    }
    if (data.containsKey('base_title')) {
      context.handle(
        _baseTitleMeta,
        baseTitle.isAcceptableOrUnknown(data['base_title']!, _baseTitleMeta),
      );
    }
    if (data.containsKey('base_category')) {
      context.handle(
        _baseCategoryMeta,
        baseCategory.isAcceptableOrUnknown(
          data['base_category']!,
          _baseCategoryMeta,
        ),
      );
    }
    if (data.containsKey('base_favorite')) {
      context.handle(
        _baseFavoriteMeta,
        baseFavorite.isAcceptableOrUnknown(
          data['base_favorite']!,
          _baseFavoriteMeta,
        ),
      );
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('dav_path')) {
      context.handle(
        _davPathMeta,
        davPath.isAcceptableOrUnknown(data['dav_path']!, _davPathMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {accountId, remoteId},
  ];
  @override
  LocalNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      favorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}favorite'],
      )!,
      readonly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}readonly'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      baseContent: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_content'],
      ),
      baseTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_title'],
      ),
      baseCategory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}base_category'],
      ),
      baseFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}base_favorite'],
      ),
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      davPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dav_path'],
      ),
    );
  }

  @override
  $LocalNotesTable createAlias(String alias) {
    return $LocalNotesTable(attachedDatabase, alias);
  }
}

class LocalNote extends DataClass implements Insertable<LocalNote> {
  final String id;
  final String accountId;
  final int? remoteId;
  final String title;
  final String content;
  final String category;
  final bool favorite;
  final bool readonly;
  final int revision;
  final String? etag;
  final String? baseContent;
  final String? baseTitle;
  final String? baseCategory;
  final bool? baseFavorite;
  final String syncState;
  final int updatedAt;

  /// `note` is listed by the Notes API; `shared` is a file somebody shared
  /// with the account, outside its Notes folder, synced over WebDAV at
  /// [davPath]. [remoteId] of a shared note is its file id, [etag] the WebDAV
  /// entity tag.
  final String kind;
  final String? davPath;
  const LocalNote({
    required this.id,
    required this.accountId,
    this.remoteId,
    required this.title,
    required this.content,
    required this.category,
    required this.favorite,
    required this.readonly,
    required this.revision,
    this.etag,
    this.baseContent,
    this.baseTitle,
    this.baseCategory,
    this.baseFavorite,
    required this.syncState,
    required this.updatedAt,
    required this.kind,
    this.davPath,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<int>(remoteId);
    }
    map['title'] = Variable<String>(title);
    map['content'] = Variable<String>(content);
    map['category'] = Variable<String>(category);
    map['favorite'] = Variable<bool>(favorite);
    map['readonly'] = Variable<bool>(readonly);
    map['revision'] = Variable<int>(revision);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    if (!nullToAbsent || baseContent != null) {
      map['base_content'] = Variable<String>(baseContent);
    }
    if (!nullToAbsent || baseTitle != null) {
      map['base_title'] = Variable<String>(baseTitle);
    }
    if (!nullToAbsent || baseCategory != null) {
      map['base_category'] = Variable<String>(baseCategory);
    }
    if (!nullToAbsent || baseFavorite != null) {
      map['base_favorite'] = Variable<bool>(baseFavorite);
    }
    map['sync_state'] = Variable<String>(syncState);
    map['updated_at'] = Variable<int>(updatedAt);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || davPath != null) {
      map['dav_path'] = Variable<String>(davPath);
    }
    return map;
  }

  LocalNotesCompanion toCompanion(bool nullToAbsent) {
    return LocalNotesCompanion(
      id: Value(id),
      accountId: Value(accountId),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      title: Value(title),
      content: Value(content),
      category: Value(category),
      favorite: Value(favorite),
      readonly: Value(readonly),
      revision: Value(revision),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      baseContent: baseContent == null && nullToAbsent
          ? const Value.absent()
          : Value(baseContent),
      baseTitle: baseTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(baseTitle),
      baseCategory: baseCategory == null && nullToAbsent
          ? const Value.absent()
          : Value(baseCategory),
      baseFavorite: baseFavorite == null && nullToAbsent
          ? const Value.absent()
          : Value(baseFavorite),
      syncState: Value(syncState),
      updatedAt: Value(updatedAt),
      kind: Value(kind),
      davPath: davPath == null && nullToAbsent
          ? const Value.absent()
          : Value(davPath),
    );
  }

  factory LocalNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalNote(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      remoteId: serializer.fromJson<int?>(json['remoteId']),
      title: serializer.fromJson<String>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      category: serializer.fromJson<String>(json['category']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      readonly: serializer.fromJson<bool>(json['readonly']),
      revision: serializer.fromJson<int>(json['revision']),
      etag: serializer.fromJson<String?>(json['etag']),
      baseContent: serializer.fromJson<String?>(json['baseContent']),
      baseTitle: serializer.fromJson<String?>(json['baseTitle']),
      baseCategory: serializer.fromJson<String?>(json['baseCategory']),
      baseFavorite: serializer.fromJson<bool?>(json['baseFavorite']),
      syncState: serializer.fromJson<String>(json['syncState']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      kind: serializer.fromJson<String>(json['kind']),
      davPath: serializer.fromJson<String?>(json['davPath']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'remoteId': serializer.toJson<int?>(remoteId),
      'title': serializer.toJson<String>(title),
      'content': serializer.toJson<String>(content),
      'category': serializer.toJson<String>(category),
      'favorite': serializer.toJson<bool>(favorite),
      'readonly': serializer.toJson<bool>(readonly),
      'revision': serializer.toJson<int>(revision),
      'etag': serializer.toJson<String?>(etag),
      'baseContent': serializer.toJson<String?>(baseContent),
      'baseTitle': serializer.toJson<String?>(baseTitle),
      'baseCategory': serializer.toJson<String?>(baseCategory),
      'baseFavorite': serializer.toJson<bool?>(baseFavorite),
      'syncState': serializer.toJson<String>(syncState),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'kind': serializer.toJson<String>(kind),
      'davPath': serializer.toJson<String?>(davPath),
    };
  }

  LocalNote copyWith({
    String? id,
    String? accountId,
    Value<int?> remoteId = const Value.absent(),
    String? title,
    String? content,
    String? category,
    bool? favorite,
    bool? readonly,
    int? revision,
    Value<String?> etag = const Value.absent(),
    Value<String?> baseContent = const Value.absent(),
    Value<String?> baseTitle = const Value.absent(),
    Value<String?> baseCategory = const Value.absent(),
    Value<bool?> baseFavorite = const Value.absent(),
    String? syncState,
    int? updatedAt,
    String? kind,
    Value<String?> davPath = const Value.absent(),
  }) => LocalNote(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    title: title ?? this.title,
    content: content ?? this.content,
    category: category ?? this.category,
    favorite: favorite ?? this.favorite,
    readonly: readonly ?? this.readonly,
    revision: revision ?? this.revision,
    etag: etag.present ? etag.value : this.etag,
    baseContent: baseContent.present ? baseContent.value : this.baseContent,
    baseTitle: baseTitle.present ? baseTitle.value : this.baseTitle,
    baseCategory: baseCategory.present ? baseCategory.value : this.baseCategory,
    baseFavorite: baseFavorite.present ? baseFavorite.value : this.baseFavorite,
    syncState: syncState ?? this.syncState,
    updatedAt: updatedAt ?? this.updatedAt,
    kind: kind ?? this.kind,
    davPath: davPath.present ? davPath.value : this.davPath,
  );
  LocalNote copyWithCompanion(LocalNotesCompanion data) {
    return LocalNote(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      category: data.category.present ? data.category.value : this.category,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      readonly: data.readonly.present ? data.readonly.value : this.readonly,
      revision: data.revision.present ? data.revision.value : this.revision,
      etag: data.etag.present ? data.etag.value : this.etag,
      baseContent: data.baseContent.present
          ? data.baseContent.value
          : this.baseContent,
      baseTitle: data.baseTitle.present ? data.baseTitle.value : this.baseTitle,
      baseCategory: data.baseCategory.present
          ? data.baseCategory.value
          : this.baseCategory,
      baseFavorite: data.baseFavorite.present
          ? data.baseFavorite.value
          : this.baseFavorite,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      kind: data.kind.present ? data.kind.value : this.kind,
      davPath: data.davPath.present ? data.davPath.value : this.davPath,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalNote(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('favorite: $favorite, ')
          ..write('readonly: $readonly, ')
          ..write('revision: $revision, ')
          ..write('etag: $etag, ')
          ..write('baseContent: $baseContent, ')
          ..write('baseTitle: $baseTitle, ')
          ..write('baseCategory: $baseCategory, ')
          ..write('baseFavorite: $baseFavorite, ')
          ..write('syncState: $syncState, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('davPath: $davPath')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    remoteId,
    title,
    content,
    category,
    favorite,
    readonly,
    revision,
    etag,
    baseContent,
    baseTitle,
    baseCategory,
    baseFavorite,
    syncState,
    updatedAt,
    kind,
    davPath,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalNote &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.remoteId == this.remoteId &&
          other.title == this.title &&
          other.content == this.content &&
          other.category == this.category &&
          other.favorite == this.favorite &&
          other.readonly == this.readonly &&
          other.revision == this.revision &&
          other.etag == this.etag &&
          other.baseContent == this.baseContent &&
          other.baseTitle == this.baseTitle &&
          other.baseCategory == this.baseCategory &&
          other.baseFavorite == this.baseFavorite &&
          other.syncState == this.syncState &&
          other.updatedAt == this.updatedAt &&
          other.kind == this.kind &&
          other.davPath == this.davPath);
}

class LocalNotesCompanion extends UpdateCompanion<LocalNote> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<int?> remoteId;
  final Value<String> title;
  final Value<String> content;
  final Value<String> category;
  final Value<bool> favorite;
  final Value<bool> readonly;
  final Value<int> revision;
  final Value<String?> etag;
  final Value<String?> baseContent;
  final Value<String?> baseTitle;
  final Value<String?> baseCategory;
  final Value<bool?> baseFavorite;
  final Value<String> syncState;
  final Value<int> updatedAt;
  final Value<String> kind;
  final Value<String?> davPath;
  final Value<int> rowid;
  const LocalNotesCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.category = const Value.absent(),
    this.favorite = const Value.absent(),
    this.readonly = const Value.absent(),
    this.revision = const Value.absent(),
    this.etag = const Value.absent(),
    this.baseContent = const Value.absent(),
    this.baseTitle = const Value.absent(),
    this.baseCategory = const Value.absent(),
    this.baseFavorite = const Value.absent(),
    this.syncState = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.kind = const Value.absent(),
    this.davPath = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalNotesCompanion.insert({
    required String id,
    required String accountId,
    this.remoteId = const Value.absent(),
    required String title,
    required String content,
    this.category = const Value.absent(),
    this.favorite = const Value.absent(),
    this.readonly = const Value.absent(),
    this.revision = const Value.absent(),
    this.etag = const Value.absent(),
    this.baseContent = const Value.absent(),
    this.baseTitle = const Value.absent(),
    this.baseCategory = const Value.absent(),
    this.baseFavorite = const Value.absent(),
    this.syncState = const Value.absent(),
    required int updatedAt,
    this.kind = const Value.absent(),
    this.davPath = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       title = Value(title),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<LocalNote> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<int>? remoteId,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? category,
    Expression<bool>? favorite,
    Expression<bool>? readonly,
    Expression<int>? revision,
    Expression<String>? etag,
    Expression<String>? baseContent,
    Expression<String>? baseTitle,
    Expression<String>? baseCategory,
    Expression<bool>? baseFavorite,
    Expression<String>? syncState,
    Expression<int>? updatedAt,
    Expression<String>? kind,
    Expression<String>? davPath,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (remoteId != null) 'remote_id': remoteId,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (category != null) 'category': category,
      if (favorite != null) 'favorite': favorite,
      if (readonly != null) 'readonly': readonly,
      if (revision != null) 'revision': revision,
      if (etag != null) 'etag': etag,
      if (baseContent != null) 'base_content': baseContent,
      if (baseTitle != null) 'base_title': baseTitle,
      if (baseCategory != null) 'base_category': baseCategory,
      if (baseFavorite != null) 'base_favorite': baseFavorite,
      if (syncState != null) 'sync_state': syncState,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (kind != null) 'kind': kind,
      if (davPath != null) 'dav_path': davPath,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalNotesCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<int?>? remoteId,
    Value<String>? title,
    Value<String>? content,
    Value<String>? category,
    Value<bool>? favorite,
    Value<bool>? readonly,
    Value<int>? revision,
    Value<String?>? etag,
    Value<String?>? baseContent,
    Value<String?>? baseTitle,
    Value<String?>? baseCategory,
    Value<bool?>? baseFavorite,
    Value<String>? syncState,
    Value<int>? updatedAt,
    Value<String>? kind,
    Value<String?>? davPath,
    Value<int>? rowid,
  }) {
    return LocalNotesCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      remoteId: remoteId ?? this.remoteId,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      favorite: favorite ?? this.favorite,
      readonly: readonly ?? this.readonly,
      revision: revision ?? this.revision,
      etag: etag ?? this.etag,
      baseContent: baseContent ?? this.baseContent,
      baseTitle: baseTitle ?? this.baseTitle,
      baseCategory: baseCategory ?? this.baseCategory,
      baseFavorite: baseFavorite ?? this.baseFavorite,
      syncState: syncState ?? this.syncState,
      updatedAt: updatedAt ?? this.updatedAt,
      kind: kind ?? this.kind,
      davPath: davPath ?? this.davPath,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<int>(remoteId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (readonly.present) {
      map['readonly'] = Variable<bool>(readonly.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (baseContent.present) {
      map['base_content'] = Variable<String>(baseContent.value);
    }
    if (baseTitle.present) {
      map['base_title'] = Variable<String>(baseTitle.value);
    }
    if (baseCategory.present) {
      map['base_category'] = Variable<String>(baseCategory.value);
    }
    if (baseFavorite.present) {
      map['base_favorite'] = Variable<bool>(baseFavorite.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (davPath.present) {
      map['dav_path'] = Variable<String>(davPath.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalNotesCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('remoteId: $remoteId, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('category: $category, ')
          ..write('favorite: $favorite, ')
          ..write('readonly: $readonly, ')
          ..write('revision: $revision, ')
          ..write('etag: $etag, ')
          ..write('baseContent: $baseContent, ')
          ..write('baseTitle: $baseTitle, ')
          ..write('baseCategory: $baseCategory, ')
          ..write('baseFavorite: $baseFavorite, ')
          ..write('syncState: $syncState, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('kind: $kind, ')
          ..write('davPath: $davPath, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OperationsTable extends Operations
    with TableInfo<$OperationsTable, Operation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OperationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<String> noteId = GeneratedColumn<String>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_notes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    noteId,
    revision,
    kind,
    state,
    payload,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'operations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Operation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
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
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Operation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Operation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $OperationsTable createAlias(String alias) {
    return $OperationsTable(attachedDatabase, alias);
  }
}

class Operation extends DataClass implements Insertable<Operation> {
  final String id;
  final String accountId;
  final String noteId;
  final int revision;
  final String kind;
  final String state;
  final String payload;
  final String? errorCode;
  const Operation({
    required this.id,
    required this.accountId,
    required this.noteId,
    required this.revision,
    required this.kind,
    required this.state,
    required this.payload,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['note_id'] = Variable<String>(noteId);
    map['revision'] = Variable<int>(revision);
    map['kind'] = Variable<String>(kind);
    map['state'] = Variable<String>(state);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  OperationsCompanion toCompanion(bool nullToAbsent) {
    return OperationsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      noteId: Value(noteId),
      revision: Value(revision),
      kind: Value(kind),
      state: Value(state),
      payload: Value(payload),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory Operation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Operation(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      noteId: serializer.fromJson<String>(json['noteId']),
      revision: serializer.fromJson<int>(json['revision']),
      kind: serializer.fromJson<String>(json['kind']),
      state: serializer.fromJson<String>(json['state']),
      payload: serializer.fromJson<String>(json['payload']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'noteId': serializer.toJson<String>(noteId),
      'revision': serializer.toJson<int>(revision),
      'kind': serializer.toJson<String>(kind),
      'state': serializer.toJson<String>(state),
      'payload': serializer.toJson<String>(payload),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  Operation copyWith({
    String? id,
    String? accountId,
    String? noteId,
    int? revision,
    String? kind,
    String? state,
    String? payload,
    Value<String?> errorCode = const Value.absent(),
  }) => Operation(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    noteId: noteId ?? this.noteId,
    revision: revision ?? this.revision,
    kind: kind ?? this.kind,
    state: state ?? this.state,
    payload: payload ?? this.payload,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  Operation copyWithCompanion(OperationsCompanion data) {
    return Operation(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      revision: data.revision.present ? data.revision.value : this.revision,
      kind: data.kind.present ? data.kind.value : this.kind,
      state: data.state.present ? data.state.value : this.state,
      payload: data.payload.present ? data.payload.value : this.payload,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Operation(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('noteId: $noteId, ')
          ..write('revision: $revision, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('payload: $payload, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    noteId,
    revision,
    kind,
    state,
    payload,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Operation &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.noteId == this.noteId &&
          other.revision == this.revision &&
          other.kind == this.kind &&
          other.state == this.state &&
          other.payload == this.payload &&
          other.errorCode == this.errorCode);
}

class OperationsCompanion extends UpdateCompanion<Operation> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> noteId;
  final Value<int> revision;
  final Value<String> kind;
  final Value<String> state;
  final Value<String> payload;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const OperationsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.noteId = const Value.absent(),
    this.revision = const Value.absent(),
    this.kind = const Value.absent(),
    this.state = const Value.absent(),
    this.payload = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OperationsCompanion.insert({
    required String id,
    required String accountId,
    required String noteId,
    required int revision,
    required String kind,
    this.state = const Value.absent(),
    required String payload,
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       noteId = Value(noteId),
       revision = Value(revision),
       kind = Value(kind),
       payload = Value(payload);
  static Insertable<Operation> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? noteId,
    Expression<int>? revision,
    Expression<String>? kind,
    Expression<String>? state,
    Expression<String>? payload,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (noteId != null) 'note_id': noteId,
      if (revision != null) 'revision': revision,
      if (kind != null) 'kind': kind,
      if (state != null) 'state': state,
      if (payload != null) 'payload': payload,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OperationsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? noteId,
    Value<int>? revision,
    Value<String>? kind,
    Value<String>? state,
    Value<String>? payload,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return OperationsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      noteId: noteId ?? this.noteId,
      revision: revision ?? this.revision,
      kind: kind ?? this.kind,
      state: state ?? this.state,
      payload: payload ?? this.payload,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<String>(noteId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OperationsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('noteId: $noteId, ')
          ..write('revision: $revision, ')
          ..write('kind: $kind, ')
          ..write('state: $state, ')
          ..write('payload: $payload, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncLeasesTable extends SyncLeases
    with TableInfo<$SyncLeasesTable, SyncLease> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncLeasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES accounts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ownerMeta = const VerificationMeta('owner');
  @override
  late final GeneratedColumn<String> owner = GeneratedColumn<String>(
    'owner',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [accountId, owner, expiresAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_leases';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncLease> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('owner')) {
      context.handle(
        _ownerMeta,
        owner.isAcceptableOrUnknown(data['owner']!, _ownerMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {accountId};
  @override
  SyncLease map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncLease(
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      owner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}owner'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
    );
  }

  @override
  $SyncLeasesTable createAlias(String alias) {
    return $SyncLeasesTable(attachedDatabase, alias);
  }
}

class SyncLease extends DataClass implements Insertable<SyncLease> {
  final String accountId;
  final String owner;
  final int expiresAt;
  const SyncLease({
    required this.accountId,
    required this.owner,
    required this.expiresAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['account_id'] = Variable<String>(accountId);
    map['owner'] = Variable<String>(owner);
    map['expires_at'] = Variable<int>(expiresAt);
    return map;
  }

  SyncLeasesCompanion toCompanion(bool nullToAbsent) {
    return SyncLeasesCompanion(
      accountId: Value(accountId),
      owner: Value(owner),
      expiresAt: Value(expiresAt),
    );
  }

  factory SyncLease.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncLease(
      accountId: serializer.fromJson<String>(json['accountId']),
      owner: serializer.fromJson<String>(json['owner']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'accountId': serializer.toJson<String>(accountId),
      'owner': serializer.toJson<String>(owner),
      'expiresAt': serializer.toJson<int>(expiresAt),
    };
  }

  SyncLease copyWith({String? accountId, String? owner, int? expiresAt}) =>
      SyncLease(
        accountId: accountId ?? this.accountId,
        owner: owner ?? this.owner,
        expiresAt: expiresAt ?? this.expiresAt,
      );
  SyncLease copyWithCompanion(SyncLeasesCompanion data) {
    return SyncLease(
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      owner: data.owner.present ? data.owner.value : this.owner,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncLease(')
          ..write('accountId: $accountId, ')
          ..write('owner: $owner, ')
          ..write('expiresAt: $expiresAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(accountId, owner, expiresAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncLease &&
          other.accountId == this.accountId &&
          other.owner == this.owner &&
          other.expiresAt == this.expiresAt);
}

class SyncLeasesCompanion extends UpdateCompanion<SyncLease> {
  final Value<String> accountId;
  final Value<String> owner;
  final Value<int> expiresAt;
  final Value<int> rowid;
  const SyncLeasesCompanion({
    this.accountId = const Value.absent(),
    this.owner = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncLeasesCompanion.insert({
    required String accountId,
    required String owner,
    required int expiresAt,
    this.rowid = const Value.absent(),
  }) : accountId = Value(accountId),
       owner = Value(owner),
       expiresAt = Value(expiresAt);
  static Insertable<SyncLease> custom({
    Expression<String>? accountId,
    Expression<String>? owner,
    Expression<int>? expiresAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (accountId != null) 'account_id': accountId,
      if (owner != null) 'owner': owner,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncLeasesCompanion copyWith({
    Value<String>? accountId,
    Value<String>? owner,
    Value<int>? expiresAt,
    Value<int>? rowid,
  }) {
    return SyncLeasesCompanion(
      accountId: accountId ?? this.accountId,
      owner: owner ?? this.owner,
      expiresAt: expiresAt ?? this.expiresAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (owner.present) {
      map['owner'] = Variable<String>(owner.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncLeasesCompanion(')
          ..write('accountId: $accountId, ')
          ..write('owner: $owner, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$NotesDatabase extends GeneratedDatabase {
  _$NotesDatabase(QueryExecutor e) : super(e);
  $NotesDatabaseManager get managers => $NotesDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $LocalNotesTable localNotes = $LocalNotesTable(this);
  late final $OperationsTable operations = $OperationsTable(this);
  late final $SyncLeasesTable syncLeases = $SyncLeasesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    localNotes,
    operations,
    syncLeases,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('local_notes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('operations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'local_notes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('operations', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'accounts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('sync_leases', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String server,
      required String loginName,
      required String credentialRef,
      Value<String> state,
      Value<int> generation,
      Value<int> mutationEpoch,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> server,
      Value<String> loginName,
      Value<String> credentialRef,
      Value<String> state,
      Value<int> generation,
      Value<int> mutationEpoch,
      Value<int> rowid,
    });

final class $$AccountsTableReferences
    extends BaseReferences<_$NotesDatabase, $AccountsTable, Account> {
  $$AccountsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalNotesTable, List<LocalNote>>
  _localNotesRefsTable(_$NotesDatabase db) => MultiTypedResultKey.fromTable(
    db.localNotes,
    aliasName: 'accounts__id__local_notes__account_id',
  );

  $$LocalNotesTableProcessedTableManager get localNotesRefs {
    final manager = $$LocalNotesTableTableManager(
      $_db,
      $_db.localNotes,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localNotesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$OperationsTable, List<Operation>>
  _operationsRefsTable(_$NotesDatabase db) => MultiTypedResultKey.fromTable(
    db.operations,
    aliasName: 'accounts__id__operations__account_id',
  );

  $$OperationsTableProcessedTableManager get operationsRefs {
    final manager = $$OperationsTableTableManager(
      $_db,
      $_db.operations,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$SyncLeasesTable, List<SyncLease>>
  _syncLeasesRefsTable(_$NotesDatabase db) => MultiTypedResultKey.fromTable(
    db.syncLeases,
    aliasName: 'accounts__id__sync_leases__account_id',
  );

  $$SyncLeasesTableProcessedTableManager get syncLeasesRefs {
    final manager = $$SyncLeasesTableTableManager(
      $_db,
      $_db.syncLeases,
    ).filter((f) => f.accountId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncLeasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$AccountsTableFilterComposer
    extends Composer<_$NotesDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
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

  ColumnFilters<String> get server => $composableBuilder(
    column: $table.server,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mutationEpoch => $composableBuilder(
    column: $table.mutationEpoch,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localNotesRefs(
    Expression<bool> Function($$LocalNotesTableFilterComposer f) f,
  ) {
    final $$LocalNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localNotes,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalNotesTableFilterComposer(
            $db: $db,
            $table: $db.localNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> operationsRefs(
    Expression<bool> Function($$OperationsTableFilterComposer f) f,
  ) {
    final $$OperationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncLeasesRefs(
    Expression<bool> Function($$SyncLeasesTableFilterComposer f) f,
  ) {
    final $$SyncLeasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncLeases,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncLeasesTableFilterComposer(
            $db: $db,
            $table: $db.syncLeases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableOrderingComposer
    extends Composer<_$NotesDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
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

  ColumnOrderings<String> get server => $composableBuilder(
    column: $table.server,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get loginName => $composableBuilder(
    column: $table.loginName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mutationEpoch => $composableBuilder(
    column: $table.mutationEpoch,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$NotesDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get server =>
      $composableBuilder(column: $table.server, builder: (column) => column);

  GeneratedColumn<String> get loginName =>
      $composableBuilder(column: $table.loginName, builder: (column) => column);

  GeneratedColumn<String> get credentialRef => $composableBuilder(
    column: $table.credentialRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get generation => $composableBuilder(
    column: $table.generation,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mutationEpoch => $composableBuilder(
    column: $table.mutationEpoch,
    builder: (column) => column,
  );

  Expression<T> localNotesRefs<T extends Object>(
    Expression<T> Function($$LocalNotesTableAnnotationComposer a) f,
  ) {
    final $$LocalNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localNotes,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.localNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> operationsRefs<T extends Object>(
    Expression<T> Function($$OperationsTableAnnotationComposer a) f,
  ) {
    final $$OperationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncLeasesRefs<T extends Object>(
    Expression<T> Function($$SyncLeasesTableAnnotationComposer a) f,
  ) {
    final $$SyncLeasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncLeases,
      getReferencedColumn: (t) => t.accountId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SyncLeasesTableAnnotationComposer(
            $db: $db,
            $table: $db.syncLeases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, $$AccountsTableReferences),
          Account,
          PrefetchHooks Function({
            bool localNotesRefs,
            bool operationsRefs,
            bool syncLeasesRefs,
          })
        > {
  $$AccountsTableTableManager(_$NotesDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> server = const Value.absent(),
                Value<String> loginName = const Value.absent(),
                Value<String> credentialRef = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> mutationEpoch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                server: server,
                loginName: loginName,
                credentialRef: credentialRef,
                state: state,
                generation: generation,
                mutationEpoch: mutationEpoch,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String server,
                required String loginName,
                required String credentialRef,
                Value<String> state = const Value.absent(),
                Value<int> generation = const Value.absent(),
                Value<int> mutationEpoch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                server: server,
                loginName: loginName,
                credentialRef: credentialRef,
                state: state,
                generation: generation,
                mutationEpoch: mutationEpoch,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AccountsTable, Account>(table),
                  $$AccountsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                localNotesRefs = false,
                operationsRefs = false,
                syncLeasesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (localNotesRefs) db.localNotes,
                    if (operationsRefs) db.operations,
                    if (syncLeasesRefs) db.syncLeases,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (localNotesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          LocalNote
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._localNotesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).localNotesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (operationsRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          Operation
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._operationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).operationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncLeasesRefs)
                        await $_getPrefetchedData<
                          Account,
                          $AccountsTable,
                          SyncLease
                        >(
                          currentTable: table,
                          referencedTable: $$AccountsTableReferences
                              ._syncLeasesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$AccountsTableReferences(
                                db,
                                table,
                                p0,
                              ).syncLeasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.accountId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, $$AccountsTableReferences),
      Account,
      PrefetchHooks Function({
        bool localNotesRefs,
        bool operationsRefs,
        bool syncLeasesRefs,
      })
    >;
typedef $$LocalNotesTableCreateCompanionBuilder =
    LocalNotesCompanion Function({
      required String id,
      required String accountId,
      Value<int?> remoteId,
      required String title,
      required String content,
      Value<String> category,
      Value<bool> favorite,
      Value<bool> readonly,
      Value<int> revision,
      Value<String?> etag,
      Value<String?> baseContent,
      Value<String?> baseTitle,
      Value<String?> baseCategory,
      Value<bool?> baseFavorite,
      Value<String> syncState,
      required int updatedAt,
      Value<String> kind,
      Value<String?> davPath,
      Value<int> rowid,
    });
typedef $$LocalNotesTableUpdateCompanionBuilder =
    LocalNotesCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<int?> remoteId,
      Value<String> title,
      Value<String> content,
      Value<String> category,
      Value<bool> favorite,
      Value<bool> readonly,
      Value<int> revision,
      Value<String?> etag,
      Value<String?> baseContent,
      Value<String?> baseTitle,
      Value<String?> baseCategory,
      Value<bool?> baseFavorite,
      Value<String> syncState,
      Value<int> updatedAt,
      Value<String> kind,
      Value<String?> davPath,
      Value<int> rowid,
    });

final class $$LocalNotesTableReferences
    extends BaseReferences<_$NotesDatabase, $LocalNotesTable, LocalNote> {
  $$LocalNotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$NotesDatabase db) =>
      db.accounts.createAlias('local_notes__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$OperationsTable, List<Operation>>
  _operationsRefsTable(_$NotesDatabase db) => MultiTypedResultKey.fromTable(
    db.operations,
    aliasName: 'local_notes__id__operations__note_id',
  );

  $$OperationsTableProcessedTableManager get operationsRefs {
    final manager = $$OperationsTableTableManager(
      $_db,
      $_db.operations,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_operationsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalNotesTableFilterComposer
    extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableFilterComposer({
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

  ColumnFilters<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get readonly => $composableBuilder(
    column: $table.readonly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseContent => $composableBuilder(
    column: $table.baseContent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseTitle => $composableBuilder(
    column: $table.baseTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get baseCategory => $composableBuilder(
    column: $table.baseCategory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get baseFavorite => $composableBuilder(
    column: $table.baseFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get davPath => $composableBuilder(
    column: $table.davPath,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> operationsRefs(
    Expression<bool> Function($$OperationsTableFilterComposer f) f,
  ) {
    final $$OperationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableFilterComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalNotesTableOrderingComposer
    extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableOrderingComposer({
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

  ColumnOrderings<int> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get favorite => $composableBuilder(
    column: $table.favorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get readonly => $composableBuilder(
    column: $table.readonly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseContent => $composableBuilder(
    column: $table.baseContent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseTitle => $composableBuilder(
    column: $table.baseTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get baseCategory => $composableBuilder(
    column: $table.baseCategory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get baseFavorite => $composableBuilder(
    column: $table.baseFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get davPath => $composableBuilder(
    column: $table.davPath,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalNotesTableAnnotationComposer
    extends Composer<_$NotesDatabase, $LocalNotesTable> {
  $$LocalNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get readonly =>
      $composableBuilder(column: $table.readonly, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<String> get baseContent => $composableBuilder(
    column: $table.baseContent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get baseTitle =>
      $composableBuilder(column: $table.baseTitle, builder: (column) => column);

  GeneratedColumn<String> get baseCategory => $composableBuilder(
    column: $table.baseCategory,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get baseFavorite => $composableBuilder(
    column: $table.baseFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get davPath =>
      $composableBuilder(column: $table.davPath, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> operationsRefs<T extends Object>(
    Expression<T> Function($$OperationsTableAnnotationComposer a) f,
  ) {
    final $$OperationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.operations,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$OperationsTableAnnotationComposer(
            $db: $db,
            $table: $db.operations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalNotesTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $LocalNotesTable,
          LocalNote,
          $$LocalNotesTableFilterComposer,
          $$LocalNotesTableOrderingComposer,
          $$LocalNotesTableAnnotationComposer,
          $$LocalNotesTableCreateCompanionBuilder,
          $$LocalNotesTableUpdateCompanionBuilder,
          (LocalNote, $$LocalNotesTableReferences),
          LocalNote,
          PrefetchHooks Function({bool accountId, bool operationsRefs})
        > {
  $$LocalNotesTableTableManager(_$NotesDatabase db, $LocalNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int?> remoteId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> readonly = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> baseContent = const Value.absent(),
                Value<String?> baseTitle = const Value.absent(),
                Value<String?> baseCategory = const Value.absent(),
                Value<bool?> baseFavorite = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> davPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion(
                id: id,
                accountId: accountId,
                remoteId: remoteId,
                title: title,
                content: content,
                category: category,
                favorite: favorite,
                readonly: readonly,
                revision: revision,
                etag: etag,
                baseContent: baseContent,
                baseTitle: baseTitle,
                baseCategory: baseCategory,
                baseFavorite: baseFavorite,
                syncState: syncState,
                updatedAt: updatedAt,
                kind: kind,
                davPath: davPath,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                Value<int?> remoteId = const Value.absent(),
                required String title,
                required String content,
                Value<String> category = const Value.absent(),
                Value<bool> favorite = const Value.absent(),
                Value<bool> readonly = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<String?> baseContent = const Value.absent(),
                Value<String?> baseTitle = const Value.absent(),
                Value<String?> baseCategory = const Value.absent(),
                Value<bool?> baseFavorite = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                required int updatedAt,
                Value<String> kind = const Value.absent(),
                Value<String?> davPath = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalNotesCompanion.insert(
                id: id,
                accountId: accountId,
                remoteId: remoteId,
                title: title,
                content: content,
                category: category,
                favorite: favorite,
                readonly: readonly,
                revision: revision,
                etag: etag,
                baseContent: baseContent,
                baseTitle: baseTitle,
                baseCategory: baseCategory,
                baseFavorite: baseFavorite,
                syncState: syncState,
                updatedAt: updatedAt,
                kind: kind,
                davPath: davPath,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalNotesTable, LocalNote>(table),
                  $$LocalNotesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, operationsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (operationsRefs) db.operations],
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
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$LocalNotesTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$LocalNotesTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (operationsRefs)
                    await $_getPrefetchedData<
                      LocalNote,
                      $LocalNotesTable,
                      Operation
                    >(
                      currentTable: table,
                      referencedTable: $$LocalNotesTableReferences
                          ._operationsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalNotesTableReferences(
                            db,
                            table,
                            p0,
                          ).operationsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.noteId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $LocalNotesTable,
      LocalNote,
      $$LocalNotesTableFilterComposer,
      $$LocalNotesTableOrderingComposer,
      $$LocalNotesTableAnnotationComposer,
      $$LocalNotesTableCreateCompanionBuilder,
      $$LocalNotesTableUpdateCompanionBuilder,
      (LocalNote, $$LocalNotesTableReferences),
      LocalNote,
      PrefetchHooks Function({bool accountId, bool operationsRefs})
    >;
typedef $$OperationsTableCreateCompanionBuilder =
    OperationsCompanion Function({
      required String id,
      required String accountId,
      required String noteId,
      required int revision,
      required String kind,
      Value<String> state,
      required String payload,
      Value<String?> errorCode,
      Value<int> rowid,
    });
typedef $$OperationsTableUpdateCompanionBuilder =
    OperationsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> noteId,
      Value<int> revision,
      Value<String> kind,
      Value<String> state,
      Value<String> payload,
      Value<String?> errorCode,
      Value<int> rowid,
    });

final class $$OperationsTableReferences
    extends BaseReferences<_$NotesDatabase, $OperationsTable, Operation> {
  $$OperationsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$NotesDatabase db) =>
      db.accounts.createAlias('operations__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $LocalNotesTable _noteIdTable(_$NotesDatabase db) =>
      db.localNotes.createAlias('operations__note_id__local_notes__id');

  $$LocalNotesTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<String>('note_id')!;

    final manager = $$LocalNotesTableTableManager(
      $_db,
      $_db.localNotes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$OperationsTableFilterComposer
    extends Composer<_$NotesDatabase, $OperationsTable> {
  $$OperationsTableFilterComposer({
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

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalNotesTableFilterComposer get noteId {
    final $$LocalNotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.localNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalNotesTableFilterComposer(
            $db: $db,
            $table: $db.localNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationsTableOrderingComposer
    extends Composer<_$NotesDatabase, $OperationsTable> {
  $$OperationsTableOrderingComposer({
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

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
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

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalNotesTableOrderingComposer get noteId {
    final $$LocalNotesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.localNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalNotesTableOrderingComposer(
            $db: $db,
            $table: $db.localNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationsTableAnnotationComposer
    extends Composer<_$NotesDatabase, $OperationsTable> {
  $$OperationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$LocalNotesTableAnnotationComposer get noteId {
    final $$LocalNotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.localNotes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalNotesTableAnnotationComposer(
            $db: $db,
            $table: $db.localNotes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$OperationsTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $OperationsTable,
          Operation,
          $$OperationsTableFilterComposer,
          $$OperationsTableOrderingComposer,
          $$OperationsTableAnnotationComposer,
          $$OperationsTableCreateCompanionBuilder,
          $$OperationsTableUpdateCompanionBuilder,
          (Operation, $$OperationsTableReferences),
          Operation,
          PrefetchHooks Function({bool accountId, bool noteId})
        > {
  $$OperationsTableTableManager(_$NotesDatabase db, $OperationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OperationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OperationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OperationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> noteId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion(
                id: id,
                accountId: accountId,
                noteId: noteId,
                revision: revision,
                kind: kind,
                state: state,
                payload: payload,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String noteId,
                required int revision,
                required String kind,
                Value<String> state = const Value.absent(),
                required String payload,
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OperationsCompanion.insert(
                id: id,
                accountId: accountId,
                noteId: noteId,
                revision: revision,
                kind: kind,
                state: state,
                payload: payload,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OperationsTable, Operation>(table),
                  $$OperationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false, noteId = false}) {
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
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$OperationsTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$OperationsTableReferences
                                    ._accountIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$OperationsTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$OperationsTableReferences
                                    ._noteIdTable(db)
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

typedef $$OperationsTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $OperationsTable,
      Operation,
      $$OperationsTableFilterComposer,
      $$OperationsTableOrderingComposer,
      $$OperationsTableAnnotationComposer,
      $$OperationsTableCreateCompanionBuilder,
      $$OperationsTableUpdateCompanionBuilder,
      (Operation, $$OperationsTableReferences),
      Operation,
      PrefetchHooks Function({bool accountId, bool noteId})
    >;
typedef $$SyncLeasesTableCreateCompanionBuilder =
    SyncLeasesCompanion Function({
      required String accountId,
      required String owner,
      required int expiresAt,
      Value<int> rowid,
    });
typedef $$SyncLeasesTableUpdateCompanionBuilder =
    SyncLeasesCompanion Function({
      Value<String> accountId,
      Value<String> owner,
      Value<int> expiresAt,
      Value<int> rowid,
    });

final class $$SyncLeasesTableReferences
    extends BaseReferences<_$NotesDatabase, $SyncLeasesTable, SyncLease> {
  $$SyncLeasesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $AccountsTable _accountIdTable(_$NotesDatabase db) =>
      db.accounts.createAlias('sync_leases__account_id__accounts__id');

  $$AccountsTableProcessedTableManager get accountId {
    final $_column = $_itemColumn<String>('account_id')!;

    final manager = $$AccountsTableTableManager(
      $_db,
      $_db.accounts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_accountIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SyncLeasesTableFilterComposer
    extends Composer<_$NotesDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  $$AccountsTableFilterComposer get accountId {
    final $$AccountsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableFilterComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncLeasesTableOrderingComposer
    extends Composer<_$NotesDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get owner => $composableBuilder(
    column: $table.owner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$AccountsTableOrderingComposer get accountId {
    final $$AccountsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableOrderingComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncLeasesTableAnnotationComposer
    extends Composer<_$NotesDatabase, $SyncLeasesTable> {
  $$SyncLeasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get owner =>
      $composableBuilder(column: $table.owner, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  $$AccountsTableAnnotationComposer get accountId {
    final $$AccountsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.accountId,
      referencedTable: $db.accounts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AccountsTableAnnotationComposer(
            $db: $db,
            $table: $db.accounts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SyncLeasesTableTableManager
    extends
        RootTableManager<
          _$NotesDatabase,
          $SyncLeasesTable,
          SyncLease,
          $$SyncLeasesTableFilterComposer,
          $$SyncLeasesTableOrderingComposer,
          $$SyncLeasesTableAnnotationComposer,
          $$SyncLeasesTableCreateCompanionBuilder,
          $$SyncLeasesTableUpdateCompanionBuilder,
          (SyncLease, $$SyncLeasesTableReferences),
          SyncLease,
          PrefetchHooks Function({bool accountId})
        > {
  $$SyncLeasesTableTableManager(_$NotesDatabase db, $SyncLeasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncLeasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncLeasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncLeasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> accountId = const Value.absent(),
                Value<String> owner = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncLeasesCompanion(
                accountId: accountId,
                owner: owner,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String accountId,
                required String owner,
                required int expiresAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncLeasesCompanion.insert(
                accountId: accountId,
                owner: owner,
                expiresAt: expiresAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncLeasesTable, SyncLease>(table),
                  $$SyncLeasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({accountId = false}) {
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
                    if (accountId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.accountId,
                                referencedTable: $$SyncLeasesTableReferences
                                    ._accountIdTable(db),
                                referencedColumn: $$SyncLeasesTableReferences
                                    ._accountIdTable(db)
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

typedef $$SyncLeasesTableProcessedTableManager =
    ProcessedTableManager<
      _$NotesDatabase,
      $SyncLeasesTable,
      SyncLease,
      $$SyncLeasesTableFilterComposer,
      $$SyncLeasesTableOrderingComposer,
      $$SyncLeasesTableAnnotationComposer,
      $$SyncLeasesTableCreateCompanionBuilder,
      $$SyncLeasesTableUpdateCompanionBuilder,
      (SyncLease, $$SyncLeasesTableReferences),
      SyncLease,
      PrefetchHooks Function({bool accountId})
    >;

class $NotesDatabaseManager {
  final _$NotesDatabase _db;
  $NotesDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$LocalNotesTableTableManager get localNotes =>
      $$LocalNotesTableTableManager(_db, _db.localNotes);
  $$OperationsTableTableManager get operations =>
      $$OperationsTableTableManager(_db, _db.operations);
  $$SyncLeasesTableTableManager get syncLeases =>
      $$SyncLeasesTableTableManager(_db, _db.syncLeases);
}
