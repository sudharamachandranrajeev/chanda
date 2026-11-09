// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ChandaListsTable extends ChandaLists with TableInfo<$ChandaListsTable, VaultList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
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
  static const VerificationMeta _createdMeta = const VerificationMeta('created');
  @override
  late final GeneratedColumn<String> created = GeneratedColumn<String>(
    'created',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
    'ord',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, name, created, ord];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_lists';
  @override
  VerificationContext validateIntegrity(Insertable<VaultList> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created')) {
      context.handle(_createdMeta, created.isAcceptableOrUnknown(data['created']!, _createdMeta));
    } else if (isInserting) {
      context.missing(_createdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(_ordMeta, ord.isAcceptableOrUnknown(data['ord']!, _ordMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultList(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      created: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}created'])!,
      ord: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ord'])!,
    );
  }

  @override
  $ChandaListsTable createAlias(String alias) {
    return $ChandaListsTable(attachedDatabase, alias);
  }
}

class VaultList extends DataClass implements Insertable<VaultList> {
  final String id;
  final String hlc;
  final bool deleted;
  final String name;
  final String created;
  final int ord;
  const VaultList({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.name,
    required this.created,
    required this.ord,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['name'] = Variable<String>(name);
    map['created'] = Variable<String>(created);
    map['ord'] = Variable<int>(ord);
    return map;
  }

  ChandaListsCompanion toCompanion(bool nullToAbsent) {
    return ChandaListsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      name: Value(name),
      created: Value(created),
      ord: Value(ord),
    );
  }

  factory VaultList.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultList(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      name: serializer.fromJson<String>(json['name']),
      created: serializer.fromJson<String>(json['created']),
      ord: serializer.fromJson<int>(json['ord']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'name': serializer.toJson<String>(name),
      'created': serializer.toJson<String>(created),
      'ord': serializer.toJson<int>(ord),
    };
  }

  VaultList copyWith({String? id, String? hlc, bool? deleted, String? name, String? created, int? ord}) =>
      VaultList(
        id: id ?? this.id,
        hlc: hlc ?? this.hlc,
        deleted: deleted ?? this.deleted,
        name: name ?? this.name,
        created: created ?? this.created,
        ord: ord ?? this.ord,
      );
  VaultList copyWithCompanion(ChandaListsCompanion data) {
    return VaultList(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      name: data.name.present ? data.name.value : this.name,
      created: data.created.present ? data.created.value : this.created,
      ord: data.ord.present ? data.ord.value : this.ord,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultList(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('created: $created, ')
          ..write('ord: $ord')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, name, created, ord);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultList &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.name == this.name &&
          other.created == this.created &&
          other.ord == this.ord);
}

class ChandaListsCompanion extends UpdateCompanion<VaultList> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> name;
  final Value<String> created;
  final Value<int> ord;
  final Value<int> rowid;
  const ChandaListsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.name = const Value.absent(),
    this.created = const Value.absent(),
    this.ord = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaListsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String name,
    required String created,
    this.ord = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       created = Value(created);
  static Insertable<VaultList> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? name,
    Expression<String>? created,
    Expression<int>? ord,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (name != null) 'name': name,
      if (created != null) 'created': created,
      if (ord != null) 'ord': ord,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaListsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? name,
    Value<String>? created,
    Value<int>? ord,
    Value<int>? rowid,
  }) {
    return ChandaListsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      name: name ?? this.name,
      created: created ?? this.created,
      ord: ord ?? this.ord,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (created.present) {
      map['created'] = Variable<String>(created.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaListsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('name: $name, ')
          ..write('created: $created, ')
          ..write('ord: $ord, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChandaItemsTable extends ChandaItems with TableInfo<$ChandaItemsTable, VaultItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _listIdMeta = const VerificationMeta('listId');
  @override
  late final GeneratedColumn<String> listId = GeneratedColumn<String>(
    'list_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _brandMeta = const VerificationMeta('brand');
  @override
  late final GeneratedColumn<String> brand = GeneratedColumn<String>(
    'brand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _shopMeta = const VerificationMeta('shop');
  @override
  late final GeneratedColumn<String> shop = GeneratedColumn<String>(
    'shop',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productKeyMeta = const VerificationMeta('productKey');
  @override
  late final GeneratedColumn<String> productKey = GeneratedColumn<String>(
    'product_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _variantMeta = const VerificationMeta('variant');
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _imagesMeta = const VerificationMeta('images');
  @override
  late final GeneratedColumn<String> images = GeneratedColumn<String>(
    'images',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sellerMeta = const VerificationMeta('seller');
  @override
  late final GeneratedColumn<String> seller = GeneratedColumn<String>(
    'seller',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _gtinMeta = const VerificationMeta('gtin');
  @override
  late final GeneratedColumn<String> gtin = GeneratedColumn<String>(
    'gtin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mpnMeta = const VerificationMeta('mpn');
  @override
  late final GeneratedColumn<String> mpn = GeneratedColumn<String>(
    'mpn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewsMeta = const VerificationMeta('reviews');
  @override
  late final GeneratedColumn<int> reviews = GeneratedColumn<int>(
    'reviews',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _warrantyMeta = const VerificationMeta('warranty');
  @override
  late final GeneratedColumn<String> warranty = GeneratedColumn<String>(
    'warranty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wasMeta = const VerificationMeta('was');
  @override
  late final GeneratedColumn<int> was = GeneratedColumn<int>(
    'was',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shippingMeta = const VerificationMeta('shipping');
  @override
  late final GeneratedColumn<int> shipping = GeneratedColumn<int>(
    'shipping',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inStockMeta = const VerificationMeta('inStock');
  @override
  late final GeneratedColumn<bool> inStock = GeneratedColumn<bool>(
    'in_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("in_stock" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
    'target',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alertDropMeta = const VerificationMeta('alertDrop');
  @override
  late final GeneratedColumn<bool> alertDrop = GeneratedColumn<bool>(
    'alert_drop',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("alert_drop" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _alertStockMeta = const VerificationMeta('alertStock');
  @override
  late final GeneratedColumn<bool> alertStock = GeneratedColumn<bool>(
    'alert_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("alert_stock" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _watchCloseMeta = const VerificationMeta('watchClose');
  @override
  late final GeneratedColumn<bool> watchClose = GeneratedColumn<bool>(
    'watch_close',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("watch_close" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _boughtMeta = const VerificationMeta('bought');
  @override
  late final GeneratedColumn<bool> bought = GeneratedColumn<bool>(
    'bought',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("bought" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _addedMeta = const VerificationMeta('added');
  @override
  late final GeneratedColumn<String> added = GeneratedColumn<String>(
    'added',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedMeta = const VerificationMeta('checked');
  @override
  late final GeneratedColumn<String> checked = GeneratedColumn<String>(
    'checked',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ok'),
  );
  static const VerificationMeta _failuresMeta = const VerificationMeta('failures');
  @override
  late final GeneratedColumn<int> failures = GeneratedColumn<int>(
    'failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    listId,
    title,
    brand,
    shop,
    url,
    productKey,
    variant,
    note,
    tags,
    images,
    description,
    seller,
    gtin,
    mpn,
    rating,
    reviews,
    warranty,
    currency,
    price,
    was,
    shipping,
    inStock,
    target,
    alertDrop,
    alertStock,
    watchClose,
    bought,
    added,
    checked,
    status,
    failures,
    layer,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_items';
  @override
  VerificationContext validateIntegrity(Insertable<VaultItem> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('list_id')) {
      context.handle(_listIdMeta, listId.isAcceptableOrUnknown(data['list_id']!, _listIdMeta));
    } else if (isInserting) {
      context.missing(_listIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('brand')) {
      context.handle(_brandMeta, brand.isAcceptableOrUnknown(data['brand']!, _brandMeta));
    }
    if (data.containsKey('shop')) {
      context.handle(_shopMeta, shop.isAcceptableOrUnknown(data['shop']!, _shopMeta));
    } else if (isInserting) {
      context.missing(_shopMeta);
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('product_key')) {
      context.handle(
        _productKeyMeta,
        productKey.isAcceptableOrUnknown(data['product_key']!, _productKeyMeta),
      );
    }
    if (data.containsKey('variant')) {
      context.handle(_variantMeta, variant.isAcceptableOrUnknown(data['variant']!, _variantMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(_tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('images')) {
      context.handle(_imagesMeta, images.isAcceptableOrUnknown(data['images']!, _imagesMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['description']!, _descriptionMeta),
      );
    }
    if (data.containsKey('seller')) {
      context.handle(_sellerMeta, seller.isAcceptableOrUnknown(data['seller']!, _sellerMeta));
    }
    if (data.containsKey('gtin')) {
      context.handle(_gtinMeta, gtin.isAcceptableOrUnknown(data['gtin']!, _gtinMeta));
    }
    if (data.containsKey('mpn')) {
      context.handle(_mpnMeta, mpn.isAcceptableOrUnknown(data['mpn']!, _mpnMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta, rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('reviews')) {
      context.handle(_reviewsMeta, reviews.isAcceptableOrUnknown(data['reviews']!, _reviewsMeta));
    }
    if (data.containsKey('warranty')) {
      context.handle(_warrantyMeta, warranty.isAcceptableOrUnknown(data['warranty']!, _warrantyMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('price')) {
      context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('was')) {
      context.handle(_wasMeta, was.isAcceptableOrUnknown(data['was']!, _wasMeta));
    }
    if (data.containsKey('shipping')) {
      context.handle(_shippingMeta, shipping.isAcceptableOrUnknown(data['shipping']!, _shippingMeta));
    }
    if (data.containsKey('in_stock')) {
      context.handle(_inStockMeta, inStock.isAcceptableOrUnknown(data['in_stock']!, _inStockMeta));
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta, target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('alert_drop')) {
      context.handle(_alertDropMeta, alertDrop.isAcceptableOrUnknown(data['alert_drop']!, _alertDropMeta));
    }
    if (data.containsKey('alert_stock')) {
      context.handle(
        _alertStockMeta,
        alertStock.isAcceptableOrUnknown(data['alert_stock']!, _alertStockMeta),
      );
    }
    if (data.containsKey('watch_close')) {
      context.handle(
        _watchCloseMeta,
        watchClose.isAcceptableOrUnknown(data['watch_close']!, _watchCloseMeta),
      );
    }
    if (data.containsKey('bought')) {
      context.handle(_boughtMeta, bought.isAcceptableOrUnknown(data['bought']!, _boughtMeta));
    }
    if (data.containsKey('added')) {
      context.handle(_addedMeta, added.isAcceptableOrUnknown(data['added']!, _addedMeta));
    } else if (isInserting) {
      context.missing(_addedMeta);
    }
    if (data.containsKey('checked')) {
      context.handle(_checkedMeta, checked.isAcceptableOrUnknown(data['checked']!, _checkedMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('failures')) {
      context.handle(_failuresMeta, failures.isAcceptableOrUnknown(data['failures']!, _failuresMeta));
    }
    if (data.containsKey('layer')) {
      context.handle(_layerMeta, layer.isAcceptableOrUnknown(data['layer']!, _layerMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultItem(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      listId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}list_id'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      brand: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}brand'])!,
      shop: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}shop'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      productKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_key'],
      )!,
      variant: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}variant'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      tags: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}tags'])!,
      images: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}images'])!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      seller: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}seller'])!,
      gtin: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}gtin'])!,
      mpn: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mpn'])!,
      rating: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}rating']),
      reviews: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reviews']),
      warranty: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}warranty'])!,
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      price: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}price']),
      was: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}was']),
      shipping: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}shipping']),
      inStock: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}in_stock'])!,
      target: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}target']),
      alertDrop: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}alert_drop'])!,
      alertStock: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alert_stock'],
      )!,
      watchClose: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}watch_close'],
      )!,
      bought: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}bought'])!,
      added: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}added'])!,
      checked: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}checked']),
      status: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      failures: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}failures'])!,
      layer: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}layer'])!,
    );
  }

  @override
  $ChandaItemsTable createAlias(String alias) {
    return $ChandaItemsTable(attachedDatabase, alias);
  }
}

class VaultItem extends DataClass implements Insertable<VaultItem> {
  final String id;
  final String hlc;
  final bool deleted;
  final String listId;
  final String title;
  final String brand;

  /// A shop id from the catalogue (lib/domain/shops.dart), else the domain.
  final String shop;

  /// The product page, cleaned of tracking and affiliate tags.
  final String url;

  /// The shop's own product id when known (Amazon ASIN, Shein goods id).
  final String productKey;

  /// The chosen options as JSON: {"Size":"M","Colour":"Navy"}.
  final String variant;
  final String note;

  /// Comma-separated.
  final String tags;

  /// Image URLs as a JSON list; copies live on the device (lib/domain/images.dart).
  final String images;
  final String description;
  final String seller;
  final String gtin;
  final String mpn;

  /// The shop's star rating (0-5) and number of ratings, when shown.
  final double? rating;
  final int? reviews;

  /// Warranty and returns wording found on the page.
  final String warranty;
  final String currency;

  /// The latest confirmed price, its struck-through "was" price and delivery.
  final int? price;
  final int? was;
  final int? shipping;
  final bool inStock;

  /// Alert when the price is at or under this (minor units of [currency]).
  final int? target;
  final bool alertDrop;
  final bool alertStock;

  /// Checked up to four times a day instead of once.
  final bool watchClose;
  final bool bought;
  final String added;

  /// When the price was last read, and how that went: ok | needs-you (the
  /// shop wants the user present, signed in or past a check) | gone | failed.
  final String? checked;
  final String status;
  final int failures;

  /// Which part of the page the price came from (lib/domain/reading.dart).
  final String layer;
  const VaultItem({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.listId,
    required this.title,
    required this.brand,
    required this.shop,
    required this.url,
    required this.productKey,
    required this.variant,
    required this.note,
    required this.tags,
    required this.images,
    required this.description,
    required this.seller,
    required this.gtin,
    required this.mpn,
    this.rating,
    this.reviews,
    required this.warranty,
    required this.currency,
    this.price,
    this.was,
    this.shipping,
    required this.inStock,
    this.target,
    required this.alertDrop,
    required this.alertStock,
    required this.watchClose,
    required this.bought,
    required this.added,
    this.checked,
    required this.status,
    required this.failures,
    required this.layer,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['list_id'] = Variable<String>(listId);
    map['title'] = Variable<String>(title);
    map['brand'] = Variable<String>(brand);
    map['shop'] = Variable<String>(shop);
    map['url'] = Variable<String>(url);
    map['product_key'] = Variable<String>(productKey);
    map['variant'] = Variable<String>(variant);
    map['note'] = Variable<String>(note);
    map['tags'] = Variable<String>(tags);
    map['images'] = Variable<String>(images);
    map['description'] = Variable<String>(description);
    map['seller'] = Variable<String>(seller);
    map['gtin'] = Variable<String>(gtin);
    map['mpn'] = Variable<String>(mpn);
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || reviews != null) {
      map['reviews'] = Variable<int>(reviews);
    }
    map['warranty'] = Variable<String>(warranty);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    if (!nullToAbsent || was != null) {
      map['was'] = Variable<int>(was);
    }
    if (!nullToAbsent || shipping != null) {
      map['shipping'] = Variable<int>(shipping);
    }
    map['in_stock'] = Variable<bool>(inStock);
    if (!nullToAbsent || target != null) {
      map['target'] = Variable<int>(target);
    }
    map['alert_drop'] = Variable<bool>(alertDrop);
    map['alert_stock'] = Variable<bool>(alertStock);
    map['watch_close'] = Variable<bool>(watchClose);
    map['bought'] = Variable<bool>(bought);
    map['added'] = Variable<String>(added);
    if (!nullToAbsent || checked != null) {
      map['checked'] = Variable<String>(checked);
    }
    map['status'] = Variable<String>(status);
    map['failures'] = Variable<int>(failures);
    map['layer'] = Variable<String>(layer);
    return map;
  }

  ChandaItemsCompanion toCompanion(bool nullToAbsent) {
    return ChandaItemsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      listId: Value(listId),
      title: Value(title),
      brand: Value(brand),
      shop: Value(shop),
      url: Value(url),
      productKey: Value(productKey),
      variant: Value(variant),
      note: Value(note),
      tags: Value(tags),
      images: Value(images),
      description: Value(description),
      seller: Value(seller),
      gtin: Value(gtin),
      mpn: Value(mpn),
      rating: rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      reviews: reviews == null && nullToAbsent ? const Value.absent() : Value(reviews),
      warranty: Value(warranty),
      currency: Value(currency),
      price: price == null && nullToAbsent ? const Value.absent() : Value(price),
      was: was == null && nullToAbsent ? const Value.absent() : Value(was),
      shipping: shipping == null && nullToAbsent ? const Value.absent() : Value(shipping),
      inStock: Value(inStock),
      target: target == null && nullToAbsent ? const Value.absent() : Value(target),
      alertDrop: Value(alertDrop),
      alertStock: Value(alertStock),
      watchClose: Value(watchClose),
      bought: Value(bought),
      added: Value(added),
      checked: checked == null && nullToAbsent ? const Value.absent() : Value(checked),
      status: Value(status),
      failures: Value(failures),
      layer: Value(layer),
    );
  }

  factory VaultItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultItem(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      listId: serializer.fromJson<String>(json['listId']),
      title: serializer.fromJson<String>(json['title']),
      brand: serializer.fromJson<String>(json['brand']),
      shop: serializer.fromJson<String>(json['shop']),
      url: serializer.fromJson<String>(json['url']),
      productKey: serializer.fromJson<String>(json['productKey']),
      variant: serializer.fromJson<String>(json['variant']),
      note: serializer.fromJson<String>(json['note']),
      tags: serializer.fromJson<String>(json['tags']),
      images: serializer.fromJson<String>(json['images']),
      description: serializer.fromJson<String>(json['description']),
      seller: serializer.fromJson<String>(json['seller']),
      gtin: serializer.fromJson<String>(json['gtin']),
      mpn: serializer.fromJson<String>(json['mpn']),
      rating: serializer.fromJson<double?>(json['rating']),
      reviews: serializer.fromJson<int?>(json['reviews']),
      warranty: serializer.fromJson<String>(json['warranty']),
      currency: serializer.fromJson<String>(json['currency']),
      price: serializer.fromJson<int?>(json['price']),
      was: serializer.fromJson<int?>(json['was']),
      shipping: serializer.fromJson<int?>(json['shipping']),
      inStock: serializer.fromJson<bool>(json['inStock']),
      target: serializer.fromJson<int?>(json['target']),
      alertDrop: serializer.fromJson<bool>(json['alertDrop']),
      alertStock: serializer.fromJson<bool>(json['alertStock']),
      watchClose: serializer.fromJson<bool>(json['watchClose']),
      bought: serializer.fromJson<bool>(json['bought']),
      added: serializer.fromJson<String>(json['added']),
      checked: serializer.fromJson<String?>(json['checked']),
      status: serializer.fromJson<String>(json['status']),
      failures: serializer.fromJson<int>(json['failures']),
      layer: serializer.fromJson<String>(json['layer']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'listId': serializer.toJson<String>(listId),
      'title': serializer.toJson<String>(title),
      'brand': serializer.toJson<String>(brand),
      'shop': serializer.toJson<String>(shop),
      'url': serializer.toJson<String>(url),
      'productKey': serializer.toJson<String>(productKey),
      'variant': serializer.toJson<String>(variant),
      'note': serializer.toJson<String>(note),
      'tags': serializer.toJson<String>(tags),
      'images': serializer.toJson<String>(images),
      'description': serializer.toJson<String>(description),
      'seller': serializer.toJson<String>(seller),
      'gtin': serializer.toJson<String>(gtin),
      'mpn': serializer.toJson<String>(mpn),
      'rating': serializer.toJson<double?>(rating),
      'reviews': serializer.toJson<int?>(reviews),
      'warranty': serializer.toJson<String>(warranty),
      'currency': serializer.toJson<String>(currency),
      'price': serializer.toJson<int?>(price),
      'was': serializer.toJson<int?>(was),
      'shipping': serializer.toJson<int?>(shipping),
      'inStock': serializer.toJson<bool>(inStock),
      'target': serializer.toJson<int?>(target),
      'alertDrop': serializer.toJson<bool>(alertDrop),
      'alertStock': serializer.toJson<bool>(alertStock),
      'watchClose': serializer.toJson<bool>(watchClose),
      'bought': serializer.toJson<bool>(bought),
      'added': serializer.toJson<String>(added),
      'checked': serializer.toJson<String?>(checked),
      'status': serializer.toJson<String>(status),
      'failures': serializer.toJson<int>(failures),
      'layer': serializer.toJson<String>(layer),
    };
  }

  VaultItem copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? listId,
    String? title,
    String? brand,
    String? shop,
    String? url,
    String? productKey,
    String? variant,
    String? note,
    String? tags,
    String? images,
    String? description,
    String? seller,
    String? gtin,
    String? mpn,
    Value<double?> rating = const Value.absent(),
    Value<int?> reviews = const Value.absent(),
    String? warranty,
    String? currency,
    Value<int?> price = const Value.absent(),
    Value<int?> was = const Value.absent(),
    Value<int?> shipping = const Value.absent(),
    bool? inStock,
    Value<int?> target = const Value.absent(),
    bool? alertDrop,
    bool? alertStock,
    bool? watchClose,
    bool? bought,
    String? added,
    Value<String?> checked = const Value.absent(),
    String? status,
    int? failures,
    String? layer,
  }) => VaultItem(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    listId: listId ?? this.listId,
    title: title ?? this.title,
    brand: brand ?? this.brand,
    shop: shop ?? this.shop,
    url: url ?? this.url,
    productKey: productKey ?? this.productKey,
    variant: variant ?? this.variant,
    note: note ?? this.note,
    tags: tags ?? this.tags,
    images: images ?? this.images,
    description: description ?? this.description,
    seller: seller ?? this.seller,
    gtin: gtin ?? this.gtin,
    mpn: mpn ?? this.mpn,
    rating: rating.present ? rating.value : this.rating,
    reviews: reviews.present ? reviews.value : this.reviews,
    warranty: warranty ?? this.warranty,
    currency: currency ?? this.currency,
    price: price.present ? price.value : this.price,
    was: was.present ? was.value : this.was,
    shipping: shipping.present ? shipping.value : this.shipping,
    inStock: inStock ?? this.inStock,
    target: target.present ? target.value : this.target,
    alertDrop: alertDrop ?? this.alertDrop,
    alertStock: alertStock ?? this.alertStock,
    watchClose: watchClose ?? this.watchClose,
    bought: bought ?? this.bought,
    added: added ?? this.added,
    checked: checked.present ? checked.value : this.checked,
    status: status ?? this.status,
    failures: failures ?? this.failures,
    layer: layer ?? this.layer,
  );
  VaultItem copyWithCompanion(ChandaItemsCompanion data) {
    return VaultItem(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      listId: data.listId.present ? data.listId.value : this.listId,
      title: data.title.present ? data.title.value : this.title,
      brand: data.brand.present ? data.brand.value : this.brand,
      shop: data.shop.present ? data.shop.value : this.shop,
      url: data.url.present ? data.url.value : this.url,
      productKey: data.productKey.present ? data.productKey.value : this.productKey,
      variant: data.variant.present ? data.variant.value : this.variant,
      note: data.note.present ? data.note.value : this.note,
      tags: data.tags.present ? data.tags.value : this.tags,
      images: data.images.present ? data.images.value : this.images,
      description: data.description.present ? data.description.value : this.description,
      seller: data.seller.present ? data.seller.value : this.seller,
      gtin: data.gtin.present ? data.gtin.value : this.gtin,
      mpn: data.mpn.present ? data.mpn.value : this.mpn,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviews: data.reviews.present ? data.reviews.value : this.reviews,
      warranty: data.warranty.present ? data.warranty.value : this.warranty,
      currency: data.currency.present ? data.currency.value : this.currency,
      price: data.price.present ? data.price.value : this.price,
      was: data.was.present ? data.was.value : this.was,
      shipping: data.shipping.present ? data.shipping.value : this.shipping,
      inStock: data.inStock.present ? data.inStock.value : this.inStock,
      target: data.target.present ? data.target.value : this.target,
      alertDrop: data.alertDrop.present ? data.alertDrop.value : this.alertDrop,
      alertStock: data.alertStock.present ? data.alertStock.value : this.alertStock,
      watchClose: data.watchClose.present ? data.watchClose.value : this.watchClose,
      bought: data.bought.present ? data.bought.value : this.bought,
      added: data.added.present ? data.added.value : this.added,
      checked: data.checked.present ? data.checked.value : this.checked,
      status: data.status.present ? data.status.value : this.status,
      failures: data.failures.present ? data.failures.value : this.failures,
      layer: data.layer.present ? data.layer.value : this.layer,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultItem(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('brand: $brand, ')
          ..write('shop: $shop, ')
          ..write('url: $url, ')
          ..write('productKey: $productKey, ')
          ..write('variant: $variant, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('images: $images, ')
          ..write('description: $description, ')
          ..write('seller: $seller, ')
          ..write('gtin: $gtin, ')
          ..write('mpn: $mpn, ')
          ..write('rating: $rating, ')
          ..write('reviews: $reviews, ')
          ..write('warranty: $warranty, ')
          ..write('currency: $currency, ')
          ..write('price: $price, ')
          ..write('was: $was, ')
          ..write('shipping: $shipping, ')
          ..write('inStock: $inStock, ')
          ..write('target: $target, ')
          ..write('alertDrop: $alertDrop, ')
          ..write('alertStock: $alertStock, ')
          ..write('watchClose: $watchClose, ')
          ..write('bought: $bought, ')
          ..write('added: $added, ')
          ..write('checked: $checked, ')
          ..write('status: $status, ')
          ..write('failures: $failures, ')
          ..write('layer: $layer')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    hlc,
    deleted,
    listId,
    title,
    brand,
    shop,
    url,
    productKey,
    variant,
    note,
    tags,
    images,
    description,
    seller,
    gtin,
    mpn,
    rating,
    reviews,
    warranty,
    currency,
    price,
    was,
    shipping,
    inStock,
    target,
    alertDrop,
    alertStock,
    watchClose,
    bought,
    added,
    checked,
    status,
    failures,
    layer,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultItem &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.listId == this.listId &&
          other.title == this.title &&
          other.brand == this.brand &&
          other.shop == this.shop &&
          other.url == this.url &&
          other.productKey == this.productKey &&
          other.variant == this.variant &&
          other.note == this.note &&
          other.tags == this.tags &&
          other.images == this.images &&
          other.description == this.description &&
          other.seller == this.seller &&
          other.gtin == this.gtin &&
          other.mpn == this.mpn &&
          other.rating == this.rating &&
          other.reviews == this.reviews &&
          other.warranty == this.warranty &&
          other.currency == this.currency &&
          other.price == this.price &&
          other.was == this.was &&
          other.shipping == this.shipping &&
          other.inStock == this.inStock &&
          other.target == this.target &&
          other.alertDrop == this.alertDrop &&
          other.alertStock == this.alertStock &&
          other.watchClose == this.watchClose &&
          other.bought == this.bought &&
          other.added == this.added &&
          other.checked == this.checked &&
          other.status == this.status &&
          other.failures == this.failures &&
          other.layer == this.layer);
}

class ChandaItemsCompanion extends UpdateCompanion<VaultItem> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> listId;
  final Value<String> title;
  final Value<String> brand;
  final Value<String> shop;
  final Value<String> url;
  final Value<String> productKey;
  final Value<String> variant;
  final Value<String> note;
  final Value<String> tags;
  final Value<String> images;
  final Value<String> description;
  final Value<String> seller;
  final Value<String> gtin;
  final Value<String> mpn;
  final Value<double?> rating;
  final Value<int?> reviews;
  final Value<String> warranty;
  final Value<String> currency;
  final Value<int?> price;
  final Value<int?> was;
  final Value<int?> shipping;
  final Value<bool> inStock;
  final Value<int?> target;
  final Value<bool> alertDrop;
  final Value<bool> alertStock;
  final Value<bool> watchClose;
  final Value<bool> bought;
  final Value<String> added;
  final Value<String?> checked;
  final Value<String> status;
  final Value<int> failures;
  final Value<String> layer;
  final Value<int> rowid;
  const ChandaItemsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.listId = const Value.absent(),
    this.title = const Value.absent(),
    this.brand = const Value.absent(),
    this.shop = const Value.absent(),
    this.url = const Value.absent(),
    this.productKey = const Value.absent(),
    this.variant = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.images = const Value.absent(),
    this.description = const Value.absent(),
    this.seller = const Value.absent(),
    this.gtin = const Value.absent(),
    this.mpn = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviews = const Value.absent(),
    this.warranty = const Value.absent(),
    this.currency = const Value.absent(),
    this.price = const Value.absent(),
    this.was = const Value.absent(),
    this.shipping = const Value.absent(),
    this.inStock = const Value.absent(),
    this.target = const Value.absent(),
    this.alertDrop = const Value.absent(),
    this.alertStock = const Value.absent(),
    this.watchClose = const Value.absent(),
    this.bought = const Value.absent(),
    this.added = const Value.absent(),
    this.checked = const Value.absent(),
    this.status = const Value.absent(),
    this.failures = const Value.absent(),
    this.layer = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaItemsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String listId,
    required String title,
    this.brand = const Value.absent(),
    required String shop,
    required String url,
    this.productKey = const Value.absent(),
    this.variant = const Value.absent(),
    this.note = const Value.absent(),
    this.tags = const Value.absent(),
    this.images = const Value.absent(),
    this.description = const Value.absent(),
    this.seller = const Value.absent(),
    this.gtin = const Value.absent(),
    this.mpn = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviews = const Value.absent(),
    this.warranty = const Value.absent(),
    required String currency,
    this.price = const Value.absent(),
    this.was = const Value.absent(),
    this.shipping = const Value.absent(),
    this.inStock = const Value.absent(),
    this.target = const Value.absent(),
    this.alertDrop = const Value.absent(),
    this.alertStock = const Value.absent(),
    this.watchClose = const Value.absent(),
    this.bought = const Value.absent(),
    required String added,
    this.checked = const Value.absent(),
    this.status = const Value.absent(),
    this.failures = const Value.absent(),
    this.layer = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       listId = Value(listId),
       title = Value(title),
       shop = Value(shop),
       url = Value(url),
       currency = Value(currency),
       added = Value(added);
  static Insertable<VaultItem> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? listId,
    Expression<String>? title,
    Expression<String>? brand,
    Expression<String>? shop,
    Expression<String>? url,
    Expression<String>? productKey,
    Expression<String>? variant,
    Expression<String>? note,
    Expression<String>? tags,
    Expression<String>? images,
    Expression<String>? description,
    Expression<String>? seller,
    Expression<String>? gtin,
    Expression<String>? mpn,
    Expression<double>? rating,
    Expression<int>? reviews,
    Expression<String>? warranty,
    Expression<String>? currency,
    Expression<int>? price,
    Expression<int>? was,
    Expression<int>? shipping,
    Expression<bool>? inStock,
    Expression<int>? target,
    Expression<bool>? alertDrop,
    Expression<bool>? alertStock,
    Expression<bool>? watchClose,
    Expression<bool>? bought,
    Expression<String>? added,
    Expression<String>? checked,
    Expression<String>? status,
    Expression<int>? failures,
    Expression<String>? layer,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (listId != null) 'list_id': listId,
      if (title != null) 'title': title,
      if (brand != null) 'brand': brand,
      if (shop != null) 'shop': shop,
      if (url != null) 'url': url,
      if (productKey != null) 'product_key': productKey,
      if (variant != null) 'variant': variant,
      if (note != null) 'note': note,
      if (tags != null) 'tags': tags,
      if (images != null) 'images': images,
      if (description != null) 'description': description,
      if (seller != null) 'seller': seller,
      if (gtin != null) 'gtin': gtin,
      if (mpn != null) 'mpn': mpn,
      if (rating != null) 'rating': rating,
      if (reviews != null) 'reviews': reviews,
      if (warranty != null) 'warranty': warranty,
      if (currency != null) 'currency': currency,
      if (price != null) 'price': price,
      if (was != null) 'was': was,
      if (shipping != null) 'shipping': shipping,
      if (inStock != null) 'in_stock': inStock,
      if (target != null) 'target': target,
      if (alertDrop != null) 'alert_drop': alertDrop,
      if (alertStock != null) 'alert_stock': alertStock,
      if (watchClose != null) 'watch_close': watchClose,
      if (bought != null) 'bought': bought,
      if (added != null) 'added': added,
      if (checked != null) 'checked': checked,
      if (status != null) 'status': status,
      if (failures != null) 'failures': failures,
      if (layer != null) 'layer': layer,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? listId,
    Value<String>? title,
    Value<String>? brand,
    Value<String>? shop,
    Value<String>? url,
    Value<String>? productKey,
    Value<String>? variant,
    Value<String>? note,
    Value<String>? tags,
    Value<String>? images,
    Value<String>? description,
    Value<String>? seller,
    Value<String>? gtin,
    Value<String>? mpn,
    Value<double?>? rating,
    Value<int?>? reviews,
    Value<String>? warranty,
    Value<String>? currency,
    Value<int?>? price,
    Value<int?>? was,
    Value<int?>? shipping,
    Value<bool>? inStock,
    Value<int?>? target,
    Value<bool>? alertDrop,
    Value<bool>? alertStock,
    Value<bool>? watchClose,
    Value<bool>? bought,
    Value<String>? added,
    Value<String?>? checked,
    Value<String>? status,
    Value<int>? failures,
    Value<String>? layer,
    Value<int>? rowid,
  }) {
    return ChandaItemsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      brand: brand ?? this.brand,
      shop: shop ?? this.shop,
      url: url ?? this.url,
      productKey: productKey ?? this.productKey,
      variant: variant ?? this.variant,
      note: note ?? this.note,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      description: description ?? this.description,
      seller: seller ?? this.seller,
      gtin: gtin ?? this.gtin,
      mpn: mpn ?? this.mpn,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      warranty: warranty ?? this.warranty,
      currency: currency ?? this.currency,
      price: price ?? this.price,
      was: was ?? this.was,
      shipping: shipping ?? this.shipping,
      inStock: inStock ?? this.inStock,
      target: target ?? this.target,
      alertDrop: alertDrop ?? this.alertDrop,
      alertStock: alertStock ?? this.alertStock,
      watchClose: watchClose ?? this.watchClose,
      bought: bought ?? this.bought,
      added: added ?? this.added,
      checked: checked ?? this.checked,
      status: status ?? this.status,
      failures: failures ?? this.failures,
      layer: layer ?? this.layer,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (listId.present) {
      map['list_id'] = Variable<String>(listId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (brand.present) {
      map['brand'] = Variable<String>(brand.value);
    }
    if (shop.present) {
      map['shop'] = Variable<String>(shop.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (productKey.present) {
      map['product_key'] = Variable<String>(productKey.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (images.present) {
      map['images'] = Variable<String>(images.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (seller.present) {
      map['seller'] = Variable<String>(seller.value);
    }
    if (gtin.present) {
      map['gtin'] = Variable<String>(gtin.value);
    }
    if (mpn.present) {
      map['mpn'] = Variable<String>(mpn.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (reviews.present) {
      map['reviews'] = Variable<int>(reviews.value);
    }
    if (warranty.present) {
      map['warranty'] = Variable<String>(warranty.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (was.present) {
      map['was'] = Variable<int>(was.value);
    }
    if (shipping.present) {
      map['shipping'] = Variable<int>(shipping.value);
    }
    if (inStock.present) {
      map['in_stock'] = Variable<bool>(inStock.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (alertDrop.present) {
      map['alert_drop'] = Variable<bool>(alertDrop.value);
    }
    if (alertStock.present) {
      map['alert_stock'] = Variable<bool>(alertStock.value);
    }
    if (watchClose.present) {
      map['watch_close'] = Variable<bool>(watchClose.value);
    }
    if (bought.present) {
      map['bought'] = Variable<bool>(bought.value);
    }
    if (added.present) {
      map['added'] = Variable<String>(added.value);
    }
    if (checked.present) {
      map['checked'] = Variable<String>(checked.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (failures.present) {
      map['failures'] = Variable<int>(failures.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaItemsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('listId: $listId, ')
          ..write('title: $title, ')
          ..write('brand: $brand, ')
          ..write('shop: $shop, ')
          ..write('url: $url, ')
          ..write('productKey: $productKey, ')
          ..write('variant: $variant, ')
          ..write('note: $note, ')
          ..write('tags: $tags, ')
          ..write('images: $images, ')
          ..write('description: $description, ')
          ..write('seller: $seller, ')
          ..write('gtin: $gtin, ')
          ..write('mpn: $mpn, ')
          ..write('rating: $rating, ')
          ..write('reviews: $reviews, ')
          ..write('warranty: $warranty, ')
          ..write('currency: $currency, ')
          ..write('price: $price, ')
          ..write('was: $was, ')
          ..write('shipping: $shipping, ')
          ..write('inStock: $inStock, ')
          ..write('target: $target, ')
          ..write('alertDrop: $alertDrop, ')
          ..write('alertStock: $alertStock, ')
          ..write('watchClose: $watchClose, ')
          ..write('bought: $bought, ')
          ..write('added: $added, ')
          ..write('checked: $checked, ')
          ..write('status: $status, ')
          ..write('failures: $failures, ')
          ..write('layer: $layer, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChandaPricesTable extends ChandaPrices with TableInfo<$ChandaPricesTable, PricePoint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaPricesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wasMeta = const VerificationMeta('was');
  @override
  late final GeneratedColumn<int> was = GeneratedColumn<int>(
    'was',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _shippingMeta = const VerificationMeta('shipping');
  @override
  late final GeneratedColumn<int> shipping = GeneratedColumn<int>(
    'shipping',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inStockMeta = const VerificationMeta('inStock');
  @override
  late final GeneratedColumn<bool> inStock = GeneratedColumn<bool>(
    'in_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("in_stock" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _seenMeta = const VerificationMeta('seen');
  @override
  late final GeneratedColumn<String> seen = GeneratedColumn<String>(
    'seen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _layerMeta = const VerificationMeta('layer');
  @override
  late final GeneratedColumn<String> layer = GeneratedColumn<String>(
    'layer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('check'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hlc,
    deleted,
    itemId,
    price,
    currency,
    was,
    shipping,
    inStock,
    seen,
    layer,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_prices';
  @override
  VerificationContext validateIntegrity(Insertable<PricePoint> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('price')) {
      context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    } else if (isInserting) {
      context.missing(_priceMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('was')) {
      context.handle(_wasMeta, was.isAcceptableOrUnknown(data['was']!, _wasMeta));
    }
    if (data.containsKey('shipping')) {
      context.handle(_shippingMeta, shipping.isAcceptableOrUnknown(data['shipping']!, _shippingMeta));
    }
    if (data.containsKey('in_stock')) {
      context.handle(_inStockMeta, inStock.isAcceptableOrUnknown(data['in_stock']!, _inStockMeta));
    }
    if (data.containsKey('seen')) {
      context.handle(_seenMeta, seen.isAcceptableOrUnknown(data['seen']!, _seenMeta));
    } else if (isInserting) {
      context.missing(_seenMeta);
    }
    if (data.containsKey('layer')) {
      context.handle(_layerMeta, layer.isAcceptableOrUnknown(data['layer']!, _layerMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PricePoint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PricePoint(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      price: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}price'])!,
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      was: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}was']),
      shipping: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}shipping']),
      inStock: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}in_stock'])!,
      seen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}seen'])!,
      layer: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}layer'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $ChandaPricesTable createAlias(String alias) {
    return $ChandaPricesTable(attachedDatabase, alias);
  }
}

class PricePoint extends DataClass implements Insertable<PricePoint> {
  final String id;
  final String hlc;
  final bool deleted;
  final String itemId;
  final int price;
  final String currency;
  final int? was;
  final int? shipping;
  final bool inStock;
  final String seen;
  final String layer;

  /// save | check | manual
  final String source;
  const PricePoint({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.itemId,
    required this.price,
    required this.currency,
    this.was,
    this.shipping,
    required this.inStock,
    required this.seen,
    required this.layer,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['item_id'] = Variable<String>(itemId);
    map['price'] = Variable<int>(price);
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || was != null) {
      map['was'] = Variable<int>(was);
    }
    if (!nullToAbsent || shipping != null) {
      map['shipping'] = Variable<int>(shipping);
    }
    map['in_stock'] = Variable<bool>(inStock);
    map['seen'] = Variable<String>(seen);
    map['layer'] = Variable<String>(layer);
    map['source'] = Variable<String>(source);
    return map;
  }

  ChandaPricesCompanion toCompanion(bool nullToAbsent) {
    return ChandaPricesCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      itemId: Value(itemId),
      price: Value(price),
      currency: Value(currency),
      was: was == null && nullToAbsent ? const Value.absent() : Value(was),
      shipping: shipping == null && nullToAbsent ? const Value.absent() : Value(shipping),
      inStock: Value(inStock),
      seen: Value(seen),
      layer: Value(layer),
      source: Value(source),
    );
  }

  factory PricePoint.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PricePoint(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      itemId: serializer.fromJson<String>(json['itemId']),
      price: serializer.fromJson<int>(json['price']),
      currency: serializer.fromJson<String>(json['currency']),
      was: serializer.fromJson<int?>(json['was']),
      shipping: serializer.fromJson<int?>(json['shipping']),
      inStock: serializer.fromJson<bool>(json['inStock']),
      seen: serializer.fromJson<String>(json['seen']),
      layer: serializer.fromJson<String>(json['layer']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'itemId': serializer.toJson<String>(itemId),
      'price': serializer.toJson<int>(price),
      'currency': serializer.toJson<String>(currency),
      'was': serializer.toJson<int?>(was),
      'shipping': serializer.toJson<int?>(shipping),
      'inStock': serializer.toJson<bool>(inStock),
      'seen': serializer.toJson<String>(seen),
      'layer': serializer.toJson<String>(layer),
      'source': serializer.toJson<String>(source),
    };
  }

  PricePoint copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? itemId,
    int? price,
    String? currency,
    Value<int?> was = const Value.absent(),
    Value<int?> shipping = const Value.absent(),
    bool? inStock,
    String? seen,
    String? layer,
    String? source,
  }) => PricePoint(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    itemId: itemId ?? this.itemId,
    price: price ?? this.price,
    currency: currency ?? this.currency,
    was: was.present ? was.value : this.was,
    shipping: shipping.present ? shipping.value : this.shipping,
    inStock: inStock ?? this.inStock,
    seen: seen ?? this.seen,
    layer: layer ?? this.layer,
    source: source ?? this.source,
  );
  PricePoint copyWithCompanion(ChandaPricesCompanion data) {
    return PricePoint(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      price: data.price.present ? data.price.value : this.price,
      currency: data.currency.present ? data.currency.value : this.currency,
      was: data.was.present ? data.was.value : this.was,
      shipping: data.shipping.present ? data.shipping.value : this.shipping,
      inStock: data.inStock.present ? data.inStock.value : this.inStock,
      seen: data.seen.present ? data.seen.value : this.seen,
      layer: data.layer.present ? data.layer.value : this.layer,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PricePoint(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('was: $was, ')
          ..write('shipping: $shipping, ')
          ..write('inStock: $inStock, ')
          ..write('seen: $seen, ')
          ..write('layer: $layer, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, hlc, deleted, itemId, price, currency, was, shipping, inStock, seen, layer, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PricePoint &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.itemId == this.itemId &&
          other.price == this.price &&
          other.currency == this.currency &&
          other.was == this.was &&
          other.shipping == this.shipping &&
          other.inStock == this.inStock &&
          other.seen == this.seen &&
          other.layer == this.layer &&
          other.source == this.source);
}

class ChandaPricesCompanion extends UpdateCompanion<PricePoint> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> itemId;
  final Value<int> price;
  final Value<String> currency;
  final Value<int?> was;
  final Value<int?> shipping;
  final Value<bool> inStock;
  final Value<String> seen;
  final Value<String> layer;
  final Value<String> source;
  final Value<int> rowid;
  const ChandaPricesCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.itemId = const Value.absent(),
    this.price = const Value.absent(),
    this.currency = const Value.absent(),
    this.was = const Value.absent(),
    this.shipping = const Value.absent(),
    this.inStock = const Value.absent(),
    this.seen = const Value.absent(),
    this.layer = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaPricesCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String itemId,
    required int price,
    required String currency,
    this.was = const Value.absent(),
    this.shipping = const Value.absent(),
    this.inStock = const Value.absent(),
    required String seen,
    this.layer = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       price = Value(price),
       currency = Value(currency),
       seen = Value(seen);
  static Insertable<PricePoint> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? itemId,
    Expression<int>? price,
    Expression<String>? currency,
    Expression<int>? was,
    Expression<int>? shipping,
    Expression<bool>? inStock,
    Expression<String>? seen,
    Expression<String>? layer,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (itemId != null) 'item_id': itemId,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
      if (was != null) 'was': was,
      if (shipping != null) 'shipping': shipping,
      if (inStock != null) 'in_stock': inStock,
      if (seen != null) 'seen': seen,
      if (layer != null) 'layer': layer,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaPricesCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? itemId,
    Value<int>? price,
    Value<String>? currency,
    Value<int?>? was,
    Value<int?>? shipping,
    Value<bool>? inStock,
    Value<String>? seen,
    Value<String>? layer,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return ChandaPricesCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      itemId: itemId ?? this.itemId,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      was: was ?? this.was,
      shipping: shipping ?? this.shipping,
      inStock: inStock ?? this.inStock,
      seen: seen ?? this.seen,
      layer: layer ?? this.layer,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (was.present) {
      map['was'] = Variable<int>(was.value);
    }
    if (shipping.present) {
      map['shipping'] = Variable<int>(shipping.value);
    }
    if (inStock.present) {
      map['in_stock'] = Variable<bool>(inStock.value);
    }
    if (seen.present) {
      map['seen'] = Variable<String>(seen.value);
    }
    if (layer.present) {
      map['layer'] = Variable<String>(layer.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaPricesCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('was: $was, ')
          ..write('shipping: $shipping, ')
          ..write('inStock: $inStock, ')
          ..write('seen: $seen, ')
          ..write('layer: $layer, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChandaAlertsTable extends ChandaAlerts with TableInfo<$ChandaAlertsTable, AlertEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaAlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  static const VerificationMeta _beforeMeta = const VerificationMeta('before');
  @override
  late final GeneratedColumn<int> before = GeneratedColumn<int>(
    'before',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _afterMeta = const VerificationMeta('after');
  @override
  late final GeneratedColumn<int> after = GeneratedColumn<int>(
    'after',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<String> at = GeneratedColumn<String>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenMeta = const VerificationMeta('seen');
  @override
  late final GeneratedColumn<bool> seen = GeneratedColumn<bool>(
    'seen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("seen" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, itemId, kind, before, after, currency, at, seen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_alerts';
  @override
  VerificationContext validateIntegrity(Insertable<AlertEvent> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('before')) {
      context.handle(_beforeMeta, before.isAcceptableOrUnknown(data['before']!, _beforeMeta));
    }
    if (data.containsKey('after')) {
      context.handle(_afterMeta, after.isAcceptableOrUnknown(data['after']!, _afterMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('seen')) {
      context.handle(_seenMeta, seen.isAcceptableOrUnknown(data['seen']!, _seenMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlertEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertEvent(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      before: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}before']),
      after: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}after']),
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      at: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}at'])!,
      seen: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}seen'])!,
    );
  }

  @override
  $ChandaAlertsTable createAlias(String alias) {
    return $ChandaAlertsTable(attachedDatabase, alias);
  }
}

class AlertEvent extends DataClass implements Insertable<AlertEvent> {
  final String id;
  final String hlc;
  final bool deleted;
  final String itemId;

  /// target | drop | stock | test
  final String kind;
  final int? before;
  final int? after;
  final String currency;
  final String at;
  final bool seen;
  const AlertEvent({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.itemId,
    required this.kind,
    this.before,
    this.after,
    required this.currency,
    required this.at,
    required this.seen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['item_id'] = Variable<String>(itemId);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || before != null) {
      map['before'] = Variable<int>(before);
    }
    if (!nullToAbsent || after != null) {
      map['after'] = Variable<int>(after);
    }
    map['currency'] = Variable<String>(currency);
    map['at'] = Variable<String>(at);
    map['seen'] = Variable<bool>(seen);
    return map;
  }

  ChandaAlertsCompanion toCompanion(bool nullToAbsent) {
    return ChandaAlertsCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      itemId: Value(itemId),
      kind: Value(kind),
      before: before == null && nullToAbsent ? const Value.absent() : Value(before),
      after: after == null && nullToAbsent ? const Value.absent() : Value(after),
      currency: Value(currency),
      at: Value(at),
      seen: Value(seen),
    );
  }

  factory AlertEvent.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertEvent(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      itemId: serializer.fromJson<String>(json['itemId']),
      kind: serializer.fromJson<String>(json['kind']),
      before: serializer.fromJson<int?>(json['before']),
      after: serializer.fromJson<int?>(json['after']),
      currency: serializer.fromJson<String>(json['currency']),
      at: serializer.fromJson<String>(json['at']),
      seen: serializer.fromJson<bool>(json['seen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'itemId': serializer.toJson<String>(itemId),
      'kind': serializer.toJson<String>(kind),
      'before': serializer.toJson<int?>(before),
      'after': serializer.toJson<int?>(after),
      'currency': serializer.toJson<String>(currency),
      'at': serializer.toJson<String>(at),
      'seen': serializer.toJson<bool>(seen),
    };
  }

  AlertEvent copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? itemId,
    String? kind,
    Value<int?> before = const Value.absent(),
    Value<int?> after = const Value.absent(),
    String? currency,
    String? at,
    bool? seen,
  }) => AlertEvent(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    itemId: itemId ?? this.itemId,
    kind: kind ?? this.kind,
    before: before.present ? before.value : this.before,
    after: after.present ? after.value : this.after,
    currency: currency ?? this.currency,
    at: at ?? this.at,
    seen: seen ?? this.seen,
  );
  AlertEvent copyWithCompanion(ChandaAlertsCompanion data) {
    return AlertEvent(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      kind: data.kind.present ? data.kind.value : this.kind,
      before: data.before.present ? data.before.value : this.before,
      after: data.after.present ? data.after.value : this.after,
      currency: data.currency.present ? data.currency.value : this.currency,
      at: data.at.present ? data.at.value : this.at,
      seen: data.seen.present ? data.seen.value : this.seen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertEvent(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('currency: $currency, ')
          ..write('at: $at, ')
          ..write('seen: $seen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, itemId, kind, before, after, currency, at, seen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertEvent &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.itemId == this.itemId &&
          other.kind == this.kind &&
          other.before == this.before &&
          other.after == this.after &&
          other.currency == this.currency &&
          other.at == this.at &&
          other.seen == this.seen);
}

class ChandaAlertsCompanion extends UpdateCompanion<AlertEvent> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> itemId;
  final Value<String> kind;
  final Value<int?> before;
  final Value<int?> after;
  final Value<String> currency;
  final Value<String> at;
  final Value<bool> seen;
  final Value<int> rowid;
  const ChandaAlertsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.itemId = const Value.absent(),
    this.kind = const Value.absent(),
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.currency = const Value.absent(),
    this.at = const Value.absent(),
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaAlertsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String itemId,
    required String kind,
    this.before = const Value.absent(),
    this.after = const Value.absent(),
    this.currency = const Value.absent(),
    required String at,
    this.seen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       kind = Value(kind),
       at = Value(at);
  static Insertable<AlertEvent> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? itemId,
    Expression<String>? kind,
    Expression<int>? before,
    Expression<int>? after,
    Expression<String>? currency,
    Expression<String>? at,
    Expression<bool>? seen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (itemId != null) 'item_id': itemId,
      if (kind != null) 'kind': kind,
      if (before != null) 'before': before,
      if (after != null) 'after': after,
      if (currency != null) 'currency': currency,
      if (at != null) 'at': at,
      if (seen != null) 'seen': seen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaAlertsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? itemId,
    Value<String>? kind,
    Value<int?>? before,
    Value<int?>? after,
    Value<String>? currency,
    Value<String>? at,
    Value<bool>? seen,
    Value<int>? rowid,
  }) {
    return ChandaAlertsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      itemId: itemId ?? this.itemId,
      kind: kind ?? this.kind,
      before: before ?? this.before,
      after: after ?? this.after,
      currency: currency ?? this.currency,
      at: at ?? this.at,
      seen: seen ?? this.seen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (before.present) {
      map['before'] = Variable<int>(before.value);
    }
    if (after.present) {
      map['after'] = Variable<int>(after.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (at.present) {
      map['at'] = Variable<String>(at.value);
    }
    if (seen.present) {
      map['seen'] = Variable<bool>(seen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaAlertsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('kind: $kind, ')
          ..write('before: $before, ')
          ..write('after: $after, ')
          ..write('currency: $currency, ')
          ..write('at: $at, ')
          ..write('seen: $seen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChandaOffersTable extends ChandaOffers with TableInfo<$ChandaOffersTable, ShopOffer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaOffersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shopMeta = const VerificationMeta('shop');
  @override
  late final GeneratedColumn<String> shop = GeneratedColumn<String>(
    'shop',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priceMeta = const VerificationMeta('price');
  @override
  late final GeneratedColumn<int> price = GeneratedColumn<int>(
    'price',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wasMeta = const VerificationMeta('was');
  @override
  late final GeneratedColumn<int> was = GeneratedColumn<int>(
    'was',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ratingMeta = const VerificationMeta('rating');
  @override
  late final GeneratedColumn<double> rating = GeneratedColumn<double>(
    'rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reviewsMeta = const VerificationMeta('reviews');
  @override
  late final GeneratedColumn<int> reviews = GeneratedColumn<int>(
    'reviews',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _inStockMeta = const VerificationMeta('inStock');
  @override
  late final GeneratedColumn<bool> inStock = GeneratedColumn<bool>(
    'in_stock',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("in_stock" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _seenMeta = const VerificationMeta('seen');
  @override
  late final GeneratedColumn<String> seen = GeneratedColumn<String>(
    'seen',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dhashMeta = const VerificationMeta('dhash');
  @override
  late final GeneratedColumn<String> dhash = GeneratedColumn<String>(
    'dhash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shop,
    url,
    title,
    image,
    price,
    currency,
    was,
    rating,
    reviews,
    inStock,
    query,
    seen,
    dhash,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_offers';
  @override
  VerificationContext validateIntegrity(Insertable<ShopOffer> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('shop')) {
      context.handle(_shopMeta, shop.isAcceptableOrUnknown(data['shop']!, _shopMeta));
    } else if (isInserting) {
      context.missing(_shopMeta);
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('image')) {
      context.handle(_imageMeta, image.isAcceptableOrUnknown(data['image']!, _imageMeta));
    }
    if (data.containsKey('price')) {
      context.handle(_priceMeta, price.isAcceptableOrUnknown(data['price']!, _priceMeta));
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta, currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('was')) {
      context.handle(_wasMeta, was.isAcceptableOrUnknown(data['was']!, _wasMeta));
    }
    if (data.containsKey('rating')) {
      context.handle(_ratingMeta, rating.isAcceptableOrUnknown(data['rating']!, _ratingMeta));
    }
    if (data.containsKey('reviews')) {
      context.handle(_reviewsMeta, reviews.isAcceptableOrUnknown(data['reviews']!, _reviewsMeta));
    }
    if (data.containsKey('in_stock')) {
      context.handle(_inStockMeta, inStock.isAcceptableOrUnknown(data['in_stock']!, _inStockMeta));
    }
    if (data.containsKey('query')) {
      context.handle(_queryMeta, query.isAcceptableOrUnknown(data['query']!, _queryMeta));
    }
    if (data.containsKey('seen')) {
      context.handle(_seenMeta, seen.isAcceptableOrUnknown(data['seen']!, _seenMeta));
    } else if (isInserting) {
      context.missing(_seenMeta);
    }
    if (data.containsKey('dhash')) {
      context.handle(_dhashMeta, dhash.isAcceptableOrUnknown(data['dhash']!, _dhashMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ShopOffer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ShopOffer(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      shop: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}shop'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      image: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}image'])!,
      price: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}price']),
      currency: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      was: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}was']),
      rating: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}rating']),
      reviews: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reviews']),
      inStock: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}in_stock'])!,
      query: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}query'])!,
      seen: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}seen'])!,
      dhash: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}dhash'])!,
    );
  }

  @override
  $ChandaOffersTable createAlias(String alias) {
    return $ChandaOffersTable(attachedDatabase, alias);
  }
}

class ShopOffer extends DataClass implements Insertable<ShopOffer> {
  /// shop + cleaned link.
  final String id;
  final String shop;
  final String url;
  final String title;
  final String image;
  final int? price;
  final String currency;
  final int? was;
  final double? rating;
  final int? reviews;
  final bool inStock;

  /// The search that last found it.
  final String query;
  final String seen;

  /// 64-bit difference hash of the picture, as 16 hex digits ('' until
  /// worked out).
  final String dhash;
  const ShopOffer({
    required this.id,
    required this.shop,
    required this.url,
    required this.title,
    required this.image,
    this.price,
    required this.currency,
    this.was,
    this.rating,
    this.reviews,
    required this.inStock,
    required this.query,
    required this.seen,
    required this.dhash,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['shop'] = Variable<String>(shop);
    map['url'] = Variable<String>(url);
    map['title'] = Variable<String>(title);
    map['image'] = Variable<String>(image);
    if (!nullToAbsent || price != null) {
      map['price'] = Variable<int>(price);
    }
    map['currency'] = Variable<String>(currency);
    if (!nullToAbsent || was != null) {
      map['was'] = Variable<int>(was);
    }
    if (!nullToAbsent || rating != null) {
      map['rating'] = Variable<double>(rating);
    }
    if (!nullToAbsent || reviews != null) {
      map['reviews'] = Variable<int>(reviews);
    }
    map['in_stock'] = Variable<bool>(inStock);
    map['query'] = Variable<String>(query);
    map['seen'] = Variable<String>(seen);
    map['dhash'] = Variable<String>(dhash);
    return map;
  }

  ChandaOffersCompanion toCompanion(bool nullToAbsent) {
    return ChandaOffersCompanion(
      id: Value(id),
      shop: Value(shop),
      url: Value(url),
      title: Value(title),
      image: Value(image),
      price: price == null && nullToAbsent ? const Value.absent() : Value(price),
      currency: Value(currency),
      was: was == null && nullToAbsent ? const Value.absent() : Value(was),
      rating: rating == null && nullToAbsent ? const Value.absent() : Value(rating),
      reviews: reviews == null && nullToAbsent ? const Value.absent() : Value(reviews),
      inStock: Value(inStock),
      query: Value(query),
      seen: Value(seen),
      dhash: Value(dhash),
    );
  }

  factory ShopOffer.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ShopOffer(
      id: serializer.fromJson<String>(json['id']),
      shop: serializer.fromJson<String>(json['shop']),
      url: serializer.fromJson<String>(json['url']),
      title: serializer.fromJson<String>(json['title']),
      image: serializer.fromJson<String>(json['image']),
      price: serializer.fromJson<int?>(json['price']),
      currency: serializer.fromJson<String>(json['currency']),
      was: serializer.fromJson<int?>(json['was']),
      rating: serializer.fromJson<double?>(json['rating']),
      reviews: serializer.fromJson<int?>(json['reviews']),
      inStock: serializer.fromJson<bool>(json['inStock']),
      query: serializer.fromJson<String>(json['query']),
      seen: serializer.fromJson<String>(json['seen']),
      dhash: serializer.fromJson<String>(json['dhash']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shop': serializer.toJson<String>(shop),
      'url': serializer.toJson<String>(url),
      'title': serializer.toJson<String>(title),
      'image': serializer.toJson<String>(image),
      'price': serializer.toJson<int?>(price),
      'currency': serializer.toJson<String>(currency),
      'was': serializer.toJson<int?>(was),
      'rating': serializer.toJson<double?>(rating),
      'reviews': serializer.toJson<int?>(reviews),
      'inStock': serializer.toJson<bool>(inStock),
      'query': serializer.toJson<String>(query),
      'seen': serializer.toJson<String>(seen),
      'dhash': serializer.toJson<String>(dhash),
    };
  }

  ShopOffer copyWith({
    String? id,
    String? shop,
    String? url,
    String? title,
    String? image,
    Value<int?> price = const Value.absent(),
    String? currency,
    Value<int?> was = const Value.absent(),
    Value<double?> rating = const Value.absent(),
    Value<int?> reviews = const Value.absent(),
    bool? inStock,
    String? query,
    String? seen,
    String? dhash,
  }) => ShopOffer(
    id: id ?? this.id,
    shop: shop ?? this.shop,
    url: url ?? this.url,
    title: title ?? this.title,
    image: image ?? this.image,
    price: price.present ? price.value : this.price,
    currency: currency ?? this.currency,
    was: was.present ? was.value : this.was,
    rating: rating.present ? rating.value : this.rating,
    reviews: reviews.present ? reviews.value : this.reviews,
    inStock: inStock ?? this.inStock,
    query: query ?? this.query,
    seen: seen ?? this.seen,
    dhash: dhash ?? this.dhash,
  );
  ShopOffer copyWithCompanion(ChandaOffersCompanion data) {
    return ShopOffer(
      id: data.id.present ? data.id.value : this.id,
      shop: data.shop.present ? data.shop.value : this.shop,
      url: data.url.present ? data.url.value : this.url,
      title: data.title.present ? data.title.value : this.title,
      image: data.image.present ? data.image.value : this.image,
      price: data.price.present ? data.price.value : this.price,
      currency: data.currency.present ? data.currency.value : this.currency,
      was: data.was.present ? data.was.value : this.was,
      rating: data.rating.present ? data.rating.value : this.rating,
      reviews: data.reviews.present ? data.reviews.value : this.reviews,
      inStock: data.inStock.present ? data.inStock.value : this.inStock,
      query: data.query.present ? data.query.value : this.query,
      seen: data.seen.present ? data.seen.value : this.seen,
      dhash: data.dhash.present ? data.dhash.value : this.dhash,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ShopOffer(')
          ..write('id: $id, ')
          ..write('shop: $shop, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('image: $image, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('was: $was, ')
          ..write('rating: $rating, ')
          ..write('reviews: $reviews, ')
          ..write('inStock: $inStock, ')
          ..write('query: $query, ')
          ..write('seen: $seen, ')
          ..write('dhash: $dhash')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shop,
    url,
    title,
    image,
    price,
    currency,
    was,
    rating,
    reviews,
    inStock,
    query,
    seen,
    dhash,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ShopOffer &&
          other.id == this.id &&
          other.shop == this.shop &&
          other.url == this.url &&
          other.title == this.title &&
          other.image == this.image &&
          other.price == this.price &&
          other.currency == this.currency &&
          other.was == this.was &&
          other.rating == this.rating &&
          other.reviews == this.reviews &&
          other.inStock == this.inStock &&
          other.query == this.query &&
          other.seen == this.seen &&
          other.dhash == this.dhash);
}

class ChandaOffersCompanion extends UpdateCompanion<ShopOffer> {
  final Value<String> id;
  final Value<String> shop;
  final Value<String> url;
  final Value<String> title;
  final Value<String> image;
  final Value<int?> price;
  final Value<String> currency;
  final Value<int?> was;
  final Value<double?> rating;
  final Value<int?> reviews;
  final Value<bool> inStock;
  final Value<String> query;
  final Value<String> seen;
  final Value<String> dhash;
  final Value<int> rowid;
  const ChandaOffersCompanion({
    this.id = const Value.absent(),
    this.shop = const Value.absent(),
    this.url = const Value.absent(),
    this.title = const Value.absent(),
    this.image = const Value.absent(),
    this.price = const Value.absent(),
    this.currency = const Value.absent(),
    this.was = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviews = const Value.absent(),
    this.inStock = const Value.absent(),
    this.query = const Value.absent(),
    this.seen = const Value.absent(),
    this.dhash = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaOffersCompanion.insert({
    required String id,
    required String shop,
    required String url,
    required String title,
    this.image = const Value.absent(),
    this.price = const Value.absent(),
    required String currency,
    this.was = const Value.absent(),
    this.rating = const Value.absent(),
    this.reviews = const Value.absent(),
    this.inStock = const Value.absent(),
    this.query = const Value.absent(),
    required String seen,
    this.dhash = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shop = Value(shop),
       url = Value(url),
       title = Value(title),
       currency = Value(currency),
       seen = Value(seen);
  static Insertable<ShopOffer> custom({
    Expression<String>? id,
    Expression<String>? shop,
    Expression<String>? url,
    Expression<String>? title,
    Expression<String>? image,
    Expression<int>? price,
    Expression<String>? currency,
    Expression<int>? was,
    Expression<double>? rating,
    Expression<int>? reviews,
    Expression<bool>? inStock,
    Expression<String>? query,
    Expression<String>? seen,
    Expression<String>? dhash,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shop != null) 'shop': shop,
      if (url != null) 'url': url,
      if (title != null) 'title': title,
      if (image != null) 'image': image,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
      if (was != null) 'was': was,
      if (rating != null) 'rating': rating,
      if (reviews != null) 'reviews': reviews,
      if (inStock != null) 'in_stock': inStock,
      if (query != null) 'query': query,
      if (seen != null) 'seen': seen,
      if (dhash != null) 'dhash': dhash,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaOffersCompanion copyWith({
    Value<String>? id,
    Value<String>? shop,
    Value<String>? url,
    Value<String>? title,
    Value<String>? image,
    Value<int?>? price,
    Value<String>? currency,
    Value<int?>? was,
    Value<double?>? rating,
    Value<int?>? reviews,
    Value<bool>? inStock,
    Value<String>? query,
    Value<String>? seen,
    Value<String>? dhash,
    Value<int>? rowid,
  }) {
    return ChandaOffersCompanion(
      id: id ?? this.id,
      shop: shop ?? this.shop,
      url: url ?? this.url,
      title: title ?? this.title,
      image: image ?? this.image,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      was: was ?? this.was,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      inStock: inStock ?? this.inStock,
      query: query ?? this.query,
      seen: seen ?? this.seen,
      dhash: dhash ?? this.dhash,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shop.present) {
      map['shop'] = Variable<String>(shop.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (price.present) {
      map['price'] = Variable<int>(price.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (was.present) {
      map['was'] = Variable<int>(was.value);
    }
    if (rating.present) {
      map['rating'] = Variable<double>(rating.value);
    }
    if (reviews.present) {
      map['reviews'] = Variable<int>(reviews.value);
    }
    if (inStock.present) {
      map['in_stock'] = Variable<bool>(inStock.value);
    }
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (seen.present) {
      map['seen'] = Variable<String>(seen.value);
    }
    if (dhash.present) {
      map['dhash'] = Variable<String>(dhash.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaOffersCompanion(')
          ..write('id: $id, ')
          ..write('shop: $shop, ')
          ..write('url: $url, ')
          ..write('title: $title, ')
          ..write('image: $image, ')
          ..write('price: $price, ')
          ..write('currency: $currency, ')
          ..write('was: $was, ')
          ..write('rating: $rating, ')
          ..write('reviews: $reviews, ')
          ..write('inStock: $inStock, ')
          ..write('query: $query, ')
          ..write('seen: $seen, ')
          ..write('dhash: $dhash, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChandaMatchesTable extends ChandaMatches with TableInfo<$ChandaMatchesTable, ProductMatch> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChandaMatchesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _urlMeta = const VerificationMeta('url');
  @override
  late final GeneratedColumn<String> url = GeneratedColumn<String>(
    'url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verdictMeta = const VerificationMeta('verdict');
  @override
  late final GeneratedColumn<String> verdict = GeneratedColumn<String>(
    'verdict',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, hlc, deleted, itemId, url, verdict];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chanda_matches';
  @override
  VerificationContext validateIntegrity(Insertable<ProductMatch> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('url')) {
      context.handle(_urlMeta, url.isAcceptableOrUnknown(data['url']!, _urlMeta));
    } else if (isInserting) {
      context.missing(_urlMeta);
    }
    if (data.containsKey('verdict')) {
      context.handle(_verdictMeta, verdict.isAcceptableOrUnknown(data['verdict']!, _verdictMeta));
    } else if (isInserting) {
      context.missing(_verdictMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductMatch map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductMatch(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      url: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}url'])!,
      verdict: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}verdict'])!,
    );
  }

  @override
  $ChandaMatchesTable createAlias(String alias) {
    return $ChandaMatchesTable(attachedDatabase, alias);
  }
}

class ProductMatch extends DataClass implements Insertable<ProductMatch> {
  final String id;
  final String hlc;
  final bool deleted;
  final String itemId;
  final String url;

  /// same | different
  final String verdict;
  const ProductMatch({
    required this.id,
    required this.hlc,
    required this.deleted,
    required this.itemId,
    required this.url,
    required this.verdict,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['item_id'] = Variable<String>(itemId);
    map['url'] = Variable<String>(url);
    map['verdict'] = Variable<String>(verdict);
    return map;
  }

  ChandaMatchesCompanion toCompanion(bool nullToAbsent) {
    return ChandaMatchesCompanion(
      id: Value(id),
      hlc: Value(hlc),
      deleted: Value(deleted),
      itemId: Value(itemId),
      url: Value(url),
      verdict: Value(verdict),
    );
  }

  factory ProductMatch.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductMatch(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      itemId: serializer.fromJson<String>(json['itemId']),
      url: serializer.fromJson<String>(json['url']),
      verdict: serializer.fromJson<String>(json['verdict']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'itemId': serializer.toJson<String>(itemId),
      'url': serializer.toJson<String>(url),
      'verdict': serializer.toJson<String>(verdict),
    };
  }

  ProductMatch copyWith({
    String? id,
    String? hlc,
    bool? deleted,
    String? itemId,
    String? url,
    String? verdict,
  }) => ProductMatch(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    itemId: itemId ?? this.itemId,
    url: url ?? this.url,
    verdict: verdict ?? this.verdict,
  );
  ProductMatch copyWithCompanion(ChandaMatchesCompanion data) {
    return ProductMatch(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      url: data.url.present ? data.url.value : this.url,
      verdict: data.verdict.present ? data.verdict.value : this.verdict,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductMatch(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('url: $url, ')
          ..write('verdict: $verdict')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, itemId, url, verdict);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductMatch &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.itemId == this.itemId &&
          other.url == this.url &&
          other.verdict == this.verdict);
}

class ChandaMatchesCompanion extends UpdateCompanion<ProductMatch> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> itemId;
  final Value<String> url;
  final Value<String> verdict;
  final Value<int> rowid;
  const ChandaMatchesCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.itemId = const Value.absent(),
    this.url = const Value.absent(),
    this.verdict = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChandaMatchesCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String itemId,
    required String url,
    required String verdict,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       url = Value(url),
       verdict = Value(verdict);
  static Insertable<ProductMatch> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? itemId,
    Expression<String>? url,
    Expression<String>? verdict,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (itemId != null) 'item_id': itemId,
      if (url != null) 'url': url,
      if (verdict != null) 'verdict': verdict,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChandaMatchesCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? itemId,
    Value<String>? url,
    Value<String>? verdict,
    Value<int>? rowid,
  }) {
    return ChandaMatchesCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      itemId: itemId ?? this.itemId,
      url: url ?? this.url,
      verdict: verdict ?? this.verdict,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (url.present) {
      map['url'] = Variable<String>(url.value);
    }
    if (verdict.present) {
      map['verdict'] = Variable<String>(verdict.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChandaMatchesCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('itemId: $itemId, ')
          ..write('url: $url, ')
          ..write('verdict: $verdict, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrefsTable extends Prefs with TableInfo<$PrefsTable, Pref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
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
  List<GeneratedColumn> get $columns => [id, hlc, deleted, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prefs';
  @override
  VerificationContext validateIntegrity(Insertable<Pref> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(_hlcMeta, hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Pref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pref(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      hlc: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hlc'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $PrefsTable createAlias(String alias) {
    return $PrefsTable(attachedDatabase, alias);
  }
}

class Pref extends DataClass implements Insertable<Pref> {
  final String id;
  final String hlc;
  final bool deleted;
  final String value;
  const Pref({required this.id, required this.hlc, required this.deleted, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['hlc'] = Variable<String>(hlc);
    map['deleted'] = Variable<bool>(deleted);
    map['value'] = Variable<String>(value);
    return map;
  }

  PrefsCompanion toCompanion(bool nullToAbsent) {
    return PrefsCompanion(id: Value(id), hlc: Value(hlc), deleted: Value(deleted), value: Value(value));
  }

  factory Pref.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pref(
      id: serializer.fromJson<String>(json['id']),
      hlc: serializer.fromJson<String>(json['hlc']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'hlc': serializer.toJson<String>(hlc),
      'deleted': serializer.toJson<bool>(deleted),
      'value': serializer.toJson<String>(value),
    };
  }

  Pref copyWith({String? id, String? hlc, bool? deleted, String? value}) => Pref(
    id: id ?? this.id,
    hlc: hlc ?? this.hlc,
    deleted: deleted ?? this.deleted,
    value: value ?? this.value,
  );
  Pref copyWithCompanion(PrefsCompanion data) {
    return Pref(
      id: data.id.present ? data.id.value : this.id,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pref(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, hlc, deleted, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pref &&
          other.id == this.id &&
          other.hlc == this.hlc &&
          other.deleted == this.deleted &&
          other.value == this.value);
}

class PrefsCompanion extends UpdateCompanion<Pref> {
  final Value<String> id;
  final Value<String> hlc;
  final Value<bool> deleted;
  final Value<String> value;
  final Value<int> rowid;
  const PrefsCompanion({
    this.id = const Value.absent(),
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrefsCompanion.insert({
    required String id,
    this.hlc = const Value.absent(),
    this.deleted = const Value.absent(),
    required String value,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       value = Value(value);
  static Insertable<Pref> custom({
    Expression<String>? id,
    Expression<String>? hlc,
    Expression<bool>? deleted,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hlc != null) 'hlc': hlc,
      if (deleted != null) 'deleted': deleted,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrefsCompanion copyWith({
    Value<String>? id,
    Value<String>? hlc,
    Value<bool>? deleted,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return PrefsCompanion(
      id: id ?? this.id,
      hlc: hlc ?? this.hlc,
      deleted: deleted ?? this.deleted,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
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
    return (StringBuffer('PrefsCompanion(')
          ..write('id: $id, ')
          ..write('hlc: $hlc, ')
          ..write('deleted: $deleted, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<String> rowId = GeneratedColumn<String>(
    'row_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [entity, rowId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(Insertable<OutboxItem> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('row_id')) {
      context.handle(_rowIdMeta, rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta));
    } else if (isInserting) {
      context.missing(_rowIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, rowId};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      entity: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      rowId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}row_id'])!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq']),
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final String entity;
  final String rowId;
  final int? seq;
  const OutboxItem({required this.entity, required this.rowId, this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['row_id'] = Variable<String>(rowId);
    if (!nullToAbsent || seq != null) {
      map['seq'] = Variable<int>(seq);
    }
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      entity: Value(entity),
      rowId: Value(rowId),
      seq: seq == null && nullToAbsent ? const Value.absent() : Value(seq),
    );
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      entity: serializer.fromJson<String>(json['entity']),
      rowId: serializer.fromJson<String>(json['rowId']),
      seq: serializer.fromJson<int?>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'rowId': serializer.toJson<String>(rowId),
      'seq': serializer.toJson<int?>(seq),
    };
  }

  OutboxItem copyWith({String? entity, String? rowId, Value<int?> seq = const Value.absent()}) => OutboxItem(
    entity: entity ?? this.entity,
    rowId: rowId ?? this.rowId,
    seq: seq.present ? seq.value : this.seq,
  );
  OutboxItem copyWithCompanion(OutboxCompanion data) {
    return OutboxItem(
      entity: data.entity.present ? data.entity.value : this.entity,
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entity, rowId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.entity == this.entity &&
          other.rowId == this.rowId &&
          other.seq == this.seq);
}

class OutboxCompanion extends UpdateCompanion<OutboxItem> {
  final Value<String> entity;
  final Value<String> rowId;
  final Value<int?> seq;
  final Value<int> rowid;
  const OutboxCompanion({
    this.entity = const Value.absent(),
    this.rowId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String entity,
    required String rowId,
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       rowId = Value(rowId);
  static Insertable<OutboxItem> custom({
    Expression<String>? entity,
    Expression<String>? rowId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (rowId != null) 'row_id': rowId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? entity,
    Value<String>? rowId,
    Value<int?>? seq,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      entity: entity ?? this.entity,
      rowId: rowId ?? this.rowId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (rowId.present) {
      map['row_id'] = Variable<String>(rowId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('entity: $entity, ')
          ..write('rowId: $rowId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta('deviceId');
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(Insertable<SyncCursor> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(_deviceIdMeta, deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta));
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      deviceId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}device_id'])!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String deviceId;
  final int seq;
  const SyncCursor({required this.deviceId, required this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(deviceId: Value(deviceId), seq: Value(seq));
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncCursor copyWith({String? deviceId, int? seq}) =>
      SyncCursor(deviceId: deviceId ?? this.deviceId, seq: seq ?? this.seq);
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor && other.deviceId == this.deviceId && other.seq == this.seq);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> deviceId;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.deviceId = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({required String deviceId, required int seq, this.rowid = const Value.absent()})
    : deviceId = Value(deviceId),
      seq = Value(seq);
  static Insertable<SyncCursor> custom({
    Expression<String>? deviceId,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({Value<String>? deviceId, Value<int>? seq, Value<int>? rowid}) {
    return SyncCursorsCompanion(
      deviceId: deviceId ?? this.deviceId,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSettingsTable extends LocalSettings with TableInfo<$LocalSettingsTable, LocalSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSettingsTable(this.attachedDatabase, [this._alias]);
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
  static const String $name = 'local_settings';
  @override
  VerificationContext validateIntegrity(Insertable<LocalSetting> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetting(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $LocalSettingsTable createAlias(String alias) {
    return $LocalSettingsTable(attachedDatabase, alias);
  }
}

class LocalSetting extends DataClass implements Insertable<LocalSetting> {
  final String key;
  final String value;
  const LocalSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocalSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory LocalSetting.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetting(
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

  LocalSetting copyWith({String? key, String? value}) =>
      LocalSetting(key: key ?? this.key, value: value ?? this.value);
  LocalSetting copyWithCompanion(LocalSettingsCompanion data) {
    return LocalSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is LocalSetting && other.key == this.key && other.value == this.value);
}

class LocalSettingsCompanion extends UpdateCompanion<LocalSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalSetting> custom({
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

  LocalSettingsCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return LocalSettingsCompanion(
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
    return (StringBuffer('LocalSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChandaListsTable chandaLists = $ChandaListsTable(this);
  late final $ChandaItemsTable chandaItems = $ChandaItemsTable(this);
  late final $ChandaPricesTable chandaPrices = $ChandaPricesTable(this);
  late final $ChandaAlertsTable chandaAlerts = $ChandaAlertsTable(this);
  late final $ChandaOffersTable chandaOffers = $ChandaOffersTable(this);
  late final $ChandaMatchesTable chandaMatches = $ChandaMatchesTable(this);
  late final $PrefsTable prefs = $PrefsTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $LocalSettingsTable localSettings = $LocalSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    chandaLists,
    chandaItems,
    chandaPrices,
    chandaAlerts,
    chandaOffers,
    chandaMatches,
    prefs,
    outbox,
    syncCursors,
    localSettings,
  ];
}

typedef $$ChandaListsTableCreateCompanionBuilder = ChandaListsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String name,
  required String created,
  Value<int> ord,
  Value<int> rowid,
});
typedef $$ChandaListsTableUpdateCompanionBuilder = ChandaListsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> name,
  Value<String> created,
  Value<int> ord,
  Value<int> rowid,
});

class $$ChandaListsTableFilterComposer extends Composer<_$AppDatabase, $ChandaListsTable> {
  $$ChandaListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => ColumnFilters(column));
}

class $$ChandaListsTableOrderingComposer extends Composer<_$AppDatabase, $ChandaListsTable> {
  $$ChandaListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => ColumnOrderings(column));
}

class $$ChandaListsTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaListsTable> {
  $$ChandaListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get created =>
      $composableBuilder(column: $table.created, builder: (column) => column);

  GeneratedColumn<int> get ord => $composableBuilder(column: $table.ord, builder: (column) => column);
}

class $$ChandaListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaListsTable,
          VaultList,
          $$ChandaListsTableFilterComposer,
          $$ChandaListsTableOrderingComposer,
          $$ChandaListsTableAnnotationComposer,
          $$ChandaListsTableCreateCompanionBuilder,
          $$ChandaListsTableUpdateCompanionBuilder,
          (VaultList, BaseReferences<_$AppDatabase, $ChandaListsTable, VaultList>),
          VaultList,
          PrefetchHooks Function()
        > {
  $$ChandaListsTableTableManager(_$AppDatabase db, $ChandaListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> created = const Value.absent(),
                Value<int> ord = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaListsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                created: created,
                ord: ord,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String name,
                required String created,
                Value<int> ord = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaListsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                name: name,
                created: created,
                ord: ord,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaListsTable, VaultList>(table),
                  BaseReferences<_$AppDatabase, $ChandaListsTable, VaultList>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaListsTable,
      VaultList,
      $$ChandaListsTableFilterComposer,
      $$ChandaListsTableOrderingComposer,
      $$ChandaListsTableAnnotationComposer,
      $$ChandaListsTableCreateCompanionBuilder,
      $$ChandaListsTableUpdateCompanionBuilder,
      (VaultList, BaseReferences<_$AppDatabase, $ChandaListsTable, VaultList>),
      VaultList,
      PrefetchHooks Function()
    >;
typedef $$ChandaItemsTableCreateCompanionBuilder = ChandaItemsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String listId,
  required String title,
  Value<String> brand,
  required String shop,
  required String url,
  Value<String> productKey,
  Value<String> variant,
  Value<String> note,
  Value<String> tags,
  Value<String> images,
  Value<String> description,
  Value<String> seller,
  Value<String> gtin,
  Value<String> mpn,
  Value<double?> rating,
  Value<int?> reviews,
  Value<String> warranty,
  required String currency,
  Value<int?> price,
  Value<int?> was,
  Value<int?> shipping,
  Value<bool> inStock,
  Value<int?> target,
  Value<bool> alertDrop,
  Value<bool> alertStock,
  Value<bool> watchClose,
  Value<bool> bought,
  required String added,
  Value<String?> checked,
  Value<String> status,
  Value<int> failures,
  Value<String> layer,
  Value<int> rowid,
});
typedef $$ChandaItemsTableUpdateCompanionBuilder = ChandaItemsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> listId,
  Value<String> title,
  Value<String> brand,
  Value<String> shop,
  Value<String> url,
  Value<String> productKey,
  Value<String> variant,
  Value<String> note,
  Value<String> tags,
  Value<String> images,
  Value<String> description,
  Value<String> seller,
  Value<String> gtin,
  Value<String> mpn,
  Value<double?> rating,
  Value<int?> reviews,
  Value<String> warranty,
  Value<String> currency,
  Value<int?> price,
  Value<int?> was,
  Value<int?> shipping,
  Value<bool> inStock,
  Value<int?> target,
  Value<bool> alertDrop,
  Value<bool> alertStock,
  Value<bool> watchClose,
  Value<bool> bought,
  Value<String> added,
  Value<String?> checked,
  Value<String> status,
  Value<int> failures,
  Value<String> layer,
  Value<int> rowid,
});

class $$ChandaItemsTableFilterComposer extends Composer<_$AppDatabase, $ChandaItemsTable> {
  $$ChandaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get productKey =>
      $composableBuilder(column: $table.productKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gtin =>
      $composableBuilder(column: $table.gtin, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mpn =>
      $composableBuilder(column: $table.mpn, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviews =>
      $composableBuilder(column: $table.reviews, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get warranty =>
      $composableBuilder(column: $table.warranty, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get alertDrop =>
      $composableBuilder(column: $table.alertDrop, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get alertStock =>
      $composableBuilder(column: $table.alertStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get watchClose =>
      $composableBuilder(column: $table.watchClose, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get bought =>
      $composableBuilder(column: $table.bought, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => ColumnFilters(column));
}

class $$ChandaItemsTableOrderingComposer extends Composer<_$AppDatabase, $ChandaItemsTable> {
  $$ChandaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get brand =>
      $composableBuilder(column: $table.brand, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get productKey =>
      $composableBuilder(column: $table.productKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gtin =>
      $composableBuilder(column: $table.gtin, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mpn =>
      $composableBuilder(column: $table.mpn, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviews =>
      $composableBuilder(column: $table.reviews, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get warranty =>
      $composableBuilder(column: $table.warranty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get alertDrop =>
      $composableBuilder(column: $table.alertDrop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get alertStock =>
      $composableBuilder(column: $table.alertStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get watchClose =>
      $composableBuilder(column: $table.watchClose, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get bought =>
      $composableBuilder(column: $table.bought, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get added =>
      $composableBuilder(column: $table.added, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => ColumnOrderings(column));
}

class $$ChandaItemsTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaItemsTable> {
  $$ChandaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get listId =>
      $composableBuilder(column: $table.listId, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get brand => $composableBuilder(column: $table.brand, builder: (column) => column);

  GeneratedColumn<String> get shop => $composableBuilder(column: $table.shop, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get productKey =>
      $composableBuilder(column: $table.productKey, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get tags => $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get images =>
      $composableBuilder(column: $table.images, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get seller =>
      $composableBuilder(column: $table.seller, builder: (column) => column);

  GeneratedColumn<String> get gtin => $composableBuilder(column: $table.gtin, builder: (column) => column);

  GeneratedColumn<String> get mpn => $composableBuilder(column: $table.mpn, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get reviews => $composableBuilder(column: $table.reviews, builder: (column) => column);

  GeneratedColumn<String> get warranty =>
      $composableBuilder(column: $table.warranty, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get price => $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<int> get was => $composableBuilder(column: $table.was, builder: (column) => column);

  GeneratedColumn<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => column);

  GeneratedColumn<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => column);

  GeneratedColumn<int> get target => $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<bool> get alertDrop =>
      $composableBuilder(column: $table.alertDrop, builder: (column) => column);

  GeneratedColumn<bool> get alertStock =>
      $composableBuilder(column: $table.alertStock, builder: (column) => column);

  GeneratedColumn<bool> get watchClose =>
      $composableBuilder(column: $table.watchClose, builder: (column) => column);

  GeneratedColumn<bool> get bought => $composableBuilder(column: $table.bought, builder: (column) => column);

  GeneratedColumn<String> get added => $composableBuilder(column: $table.added, builder: (column) => column);

  GeneratedColumn<String> get checked =>
      $composableBuilder(column: $table.checked, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get failures =>
      $composableBuilder(column: $table.failures, builder: (column) => column);

  GeneratedColumn<String> get layer => $composableBuilder(column: $table.layer, builder: (column) => column);
}

class $$ChandaItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaItemsTable,
          VaultItem,
          $$ChandaItemsTableFilterComposer,
          $$ChandaItemsTableOrderingComposer,
          $$ChandaItemsTableAnnotationComposer,
          $$ChandaItemsTableCreateCompanionBuilder,
          $$ChandaItemsTableUpdateCompanionBuilder,
          (VaultItem, BaseReferences<_$AppDatabase, $ChandaItemsTable, VaultItem>),
          VaultItem,
          PrefetchHooks Function()
        > {
  $$ChandaItemsTableTableManager(_$AppDatabase db, $ChandaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> listId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> brand = const Value.absent(),
                Value<String> shop = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> productKey = const Value.absent(),
                Value<String> variant = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> images = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> seller = const Value.absent(),
                Value<String> gtin = const Value.absent(),
                Value<String> mpn = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> reviews = const Value.absent(),
                Value<String> warranty = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<int?> was = const Value.absent(),
                Value<int?> shipping = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                Value<int?> target = const Value.absent(),
                Value<bool> alertDrop = const Value.absent(),
                Value<bool> alertStock = const Value.absent(),
                Value<bool> watchClose = const Value.absent(),
                Value<bool> bought = const Value.absent(),
                Value<String> added = const Value.absent(),
                Value<String?> checked = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaItemsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                listId: listId,
                title: title,
                brand: brand,
                shop: shop,
                url: url,
                productKey: productKey,
                variant: variant,
                note: note,
                tags: tags,
                images: images,
                description: description,
                seller: seller,
                gtin: gtin,
                mpn: mpn,
                rating: rating,
                reviews: reviews,
                warranty: warranty,
                currency: currency,
                price: price,
                was: was,
                shipping: shipping,
                inStock: inStock,
                target: target,
                alertDrop: alertDrop,
                alertStock: alertStock,
                watchClose: watchClose,
                bought: bought,
                added: added,
                checked: checked,
                status: status,
                failures: failures,
                layer: layer,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String listId,
                required String title,
                Value<String> brand = const Value.absent(),
                required String shop,
                required String url,
                Value<String> productKey = const Value.absent(),
                Value<String> variant = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> images = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> seller = const Value.absent(),
                Value<String> gtin = const Value.absent(),
                Value<String> mpn = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> reviews = const Value.absent(),
                Value<String> warranty = const Value.absent(),
                required String currency,
                Value<int?> price = const Value.absent(),
                Value<int?> was = const Value.absent(),
                Value<int?> shipping = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                Value<int?> target = const Value.absent(),
                Value<bool> alertDrop = const Value.absent(),
                Value<bool> alertStock = const Value.absent(),
                Value<bool> watchClose = const Value.absent(),
                Value<bool> bought = const Value.absent(),
                required String added,
                Value<String?> checked = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> failures = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaItemsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                listId: listId,
                title: title,
                brand: brand,
                shop: shop,
                url: url,
                productKey: productKey,
                variant: variant,
                note: note,
                tags: tags,
                images: images,
                description: description,
                seller: seller,
                gtin: gtin,
                mpn: mpn,
                rating: rating,
                reviews: reviews,
                warranty: warranty,
                currency: currency,
                price: price,
                was: was,
                shipping: shipping,
                inStock: inStock,
                target: target,
                alertDrop: alertDrop,
                alertStock: alertStock,
                watchClose: watchClose,
                bought: bought,
                added: added,
                checked: checked,
                status: status,
                failures: failures,
                layer: layer,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaItemsTable, VaultItem>(table),
                  BaseReferences<_$AppDatabase, $ChandaItemsTable, VaultItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaItemsTable,
      VaultItem,
      $$ChandaItemsTableFilterComposer,
      $$ChandaItemsTableOrderingComposer,
      $$ChandaItemsTableAnnotationComposer,
      $$ChandaItemsTableCreateCompanionBuilder,
      $$ChandaItemsTableUpdateCompanionBuilder,
      (VaultItem, BaseReferences<_$AppDatabase, $ChandaItemsTable, VaultItem>),
      VaultItem,
      PrefetchHooks Function()
    >;
typedef $$ChandaPricesTableCreateCompanionBuilder = ChandaPricesCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String itemId,
  required int price,
  required String currency,
  Value<int?> was,
  Value<int?> shipping,
  Value<bool> inStock,
  required String seen,
  Value<String> layer,
  Value<String> source,
  Value<int> rowid,
});
typedef $$ChandaPricesTableUpdateCompanionBuilder = ChandaPricesCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> itemId,
  Value<int> price,
  Value<String> currency,
  Value<int?> was,
  Value<int?> shipping,
  Value<bool> inStock,
  Value<String> seen,
  Value<String> layer,
  Value<String> source,
  Value<int> rowid,
});

class $$ChandaPricesTableFilterComposer extends Composer<_$AppDatabase, $ChandaPricesTable> {
  $$ChandaPricesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$ChandaPricesTableOrderingComposer extends Composer<_$AppDatabase, $ChandaPricesTable> {
  $$ChandaPricesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get layer =>
      $composableBuilder(column: $table.layer, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$ChandaPricesTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaPricesTable> {
  $$ChandaPricesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get price => $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get was => $composableBuilder(column: $table.was, builder: (column) => column);

  GeneratedColumn<int> get shipping =>
      $composableBuilder(column: $table.shipping, builder: (column) => column);

  GeneratedColumn<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => column);

  GeneratedColumn<String> get seen => $composableBuilder(column: $table.seen, builder: (column) => column);

  GeneratedColumn<String> get layer => $composableBuilder(column: $table.layer, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$ChandaPricesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaPricesTable,
          PricePoint,
          $$ChandaPricesTableFilterComposer,
          $$ChandaPricesTableOrderingComposer,
          $$ChandaPricesTableAnnotationComposer,
          $$ChandaPricesTableCreateCompanionBuilder,
          $$ChandaPricesTableUpdateCompanionBuilder,
          (PricePoint, BaseReferences<_$AppDatabase, $ChandaPricesTable, PricePoint>),
          PricePoint,
          PrefetchHooks Function()
        > {
  $$ChandaPricesTableTableManager(_$AppDatabase db, $ChandaPricesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaPricesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaPricesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaPricesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> price = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> was = const Value.absent(),
                Value<int?> shipping = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                Value<String> seen = const Value.absent(),
                Value<String> layer = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaPricesCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                price: price,
                currency: currency,
                was: was,
                shipping: shipping,
                inStock: inStock,
                seen: seen,
                layer: layer,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String itemId,
                required int price,
                required String currency,
                Value<int?> was = const Value.absent(),
                Value<int?> shipping = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                required String seen,
                Value<String> layer = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaPricesCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                price: price,
                currency: currency,
                was: was,
                shipping: shipping,
                inStock: inStock,
                seen: seen,
                layer: layer,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaPricesTable, PricePoint>(table),
                  BaseReferences<_$AppDatabase, $ChandaPricesTable, PricePoint>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaPricesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaPricesTable,
      PricePoint,
      $$ChandaPricesTableFilterComposer,
      $$ChandaPricesTableOrderingComposer,
      $$ChandaPricesTableAnnotationComposer,
      $$ChandaPricesTableCreateCompanionBuilder,
      $$ChandaPricesTableUpdateCompanionBuilder,
      (PricePoint, BaseReferences<_$AppDatabase, $ChandaPricesTable, PricePoint>),
      PricePoint,
      PrefetchHooks Function()
    >;
typedef $$ChandaAlertsTableCreateCompanionBuilder = ChandaAlertsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String itemId,
  required String kind,
  Value<int?> before,
  Value<int?> after,
  Value<String> currency,
  required String at,
  Value<bool> seen,
  Value<int> rowid,
});
typedef $$ChandaAlertsTableUpdateCompanionBuilder = ChandaAlertsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> itemId,
  Value<String> kind,
  Value<int?> before,
  Value<int?> after,
  Value<String> currency,
  Value<String> at,
  Value<bool> seen,
  Value<int> rowid,
});

class $$ChandaAlertsTableFilterComposer extends Composer<_$AppDatabase, $ChandaAlertsTable> {
  $$ChandaAlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get before =>
      $composableBuilder(column: $table.before, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get after =>
      $composableBuilder(column: $table.after, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnFilters(column));
}

class $$ChandaAlertsTableOrderingComposer extends Composer<_$AppDatabase, $ChandaAlertsTable> {
  $$ChandaAlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get before =>
      $composableBuilder(column: $table.before, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get after =>
      $composableBuilder(column: $table.after, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get at =>
      $composableBuilder(column: $table.at, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnOrderings(column));
}

class $$ChandaAlertsTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaAlertsTable> {
  $$ChandaAlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get before => $composableBuilder(column: $table.before, builder: (column) => column);

  GeneratedColumn<int> get after => $composableBuilder(column: $table.after, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get at => $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<bool> get seen => $composableBuilder(column: $table.seen, builder: (column) => column);
}

class $$ChandaAlertsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaAlertsTable,
          AlertEvent,
          $$ChandaAlertsTableFilterComposer,
          $$ChandaAlertsTableOrderingComposer,
          $$ChandaAlertsTableAnnotationComposer,
          $$ChandaAlertsTableCreateCompanionBuilder,
          $$ChandaAlertsTableUpdateCompanionBuilder,
          (AlertEvent, BaseReferences<_$AppDatabase, $ChandaAlertsTable, AlertEvent>),
          AlertEvent,
          PrefetchHooks Function()
        > {
  $$ChandaAlertsTableTableManager(_$AppDatabase db, $ChandaAlertsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaAlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaAlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaAlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> before = const Value.absent(),
                Value<int?> after = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> at = const Value.absent(),
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaAlertsCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                kind: kind,
                before: before,
                after: after,
                currency: currency,
                at: at,
                seen: seen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String itemId,
                required String kind,
                Value<int?> before = const Value.absent(),
                Value<int?> after = const Value.absent(),
                Value<String> currency = const Value.absent(),
                required String at,
                Value<bool> seen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaAlertsCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                kind: kind,
                before: before,
                after: after,
                currency: currency,
                at: at,
                seen: seen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaAlertsTable, AlertEvent>(table),
                  BaseReferences<_$AppDatabase, $ChandaAlertsTable, AlertEvent>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaAlertsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaAlertsTable,
      AlertEvent,
      $$ChandaAlertsTableFilterComposer,
      $$ChandaAlertsTableOrderingComposer,
      $$ChandaAlertsTableAnnotationComposer,
      $$ChandaAlertsTableCreateCompanionBuilder,
      $$ChandaAlertsTableUpdateCompanionBuilder,
      (AlertEvent, BaseReferences<_$AppDatabase, $ChandaAlertsTable, AlertEvent>),
      AlertEvent,
      PrefetchHooks Function()
    >;
typedef $$ChandaOffersTableCreateCompanionBuilder = ChandaOffersCompanion Function({
  required String id,
  required String shop,
  required String url,
  required String title,
  Value<String> image,
  Value<int?> price,
  required String currency,
  Value<int?> was,
  Value<double?> rating,
  Value<int?> reviews,
  Value<bool> inStock,
  Value<String> query,
  required String seen,
  Value<String> dhash,
  Value<int> rowid,
});
typedef $$ChandaOffersTableUpdateCompanionBuilder = ChandaOffersCompanion Function({
  Value<String> id,
  Value<String> shop,
  Value<String> url,
  Value<String> title,
  Value<String> image,
  Value<int?> price,
  Value<String> currency,
  Value<int?> was,
  Value<double?> rating,
  Value<int?> reviews,
  Value<bool> inStock,
  Value<String> query,
  Value<String> seen,
  Value<String> dhash,
  Value<int> rowid,
});

class $$ChandaOffersTableFilterComposer extends Composer<_$AppDatabase, $ChandaOffersTable> {
  $$ChandaOffersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviews =>
      $composableBuilder(column: $table.reviews, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dhash =>
      $composableBuilder(column: $table.dhash, builder: (column) => ColumnFilters(column));
}

class $$ChandaOffersTableOrderingComposer extends Composer<_$AppDatabase, $ChandaOffersTable> {
  $$ChandaOffersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shop =>
      $composableBuilder(column: $table.shop, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get price =>
      $composableBuilder(column: $table.price, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get was =>
      $composableBuilder(column: $table.was, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviews =>
      $composableBuilder(column: $table.reviews, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seen =>
      $composableBuilder(column: $table.seen, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dhash =>
      $composableBuilder(column: $table.dhash, builder: (column) => ColumnOrderings(column));
}

class $$ChandaOffersTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaOffersTable> {
  $$ChandaOffersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shop => $composableBuilder(column: $table.shop, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get image => $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<int> get price => $composableBuilder(column: $table.price, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get was => $composableBuilder(column: $table.was, builder: (column) => column);

  GeneratedColumn<double> get rating =>
      $composableBuilder(column: $table.rating, builder: (column) => column);

  GeneratedColumn<int> get reviews => $composableBuilder(column: $table.reviews, builder: (column) => column);

  GeneratedColumn<bool> get inStock =>
      $composableBuilder(column: $table.inStock, builder: (column) => column);

  GeneratedColumn<String> get query => $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get seen => $composableBuilder(column: $table.seen, builder: (column) => column);

  GeneratedColumn<String> get dhash => $composableBuilder(column: $table.dhash, builder: (column) => column);
}

class $$ChandaOffersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaOffersTable,
          ShopOffer,
          $$ChandaOffersTableFilterComposer,
          $$ChandaOffersTableOrderingComposer,
          $$ChandaOffersTableAnnotationComposer,
          $$ChandaOffersTableCreateCompanionBuilder,
          $$ChandaOffersTableUpdateCompanionBuilder,
          (ShopOffer, BaseReferences<_$AppDatabase, $ChandaOffersTable, ShopOffer>),
          ShopOffer,
          PrefetchHooks Function()
        > {
  $$ChandaOffersTableTableManager(_$AppDatabase db, $ChandaOffersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaOffersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaOffersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaOffersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shop = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> image = const Value.absent(),
                Value<int?> price = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int?> was = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> reviews = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                Value<String> query = const Value.absent(),
                Value<String> seen = const Value.absent(),
                Value<String> dhash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaOffersCompanion(
                id: id,
                shop: shop,
                url: url,
                title: title,
                image: image,
                price: price,
                currency: currency,
                was: was,
                rating: rating,
                reviews: reviews,
                inStock: inStock,
                query: query,
                seen: seen,
                dhash: dhash,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shop,
                required String url,
                required String title,
                Value<String> image = const Value.absent(),
                Value<int?> price = const Value.absent(),
                required String currency,
                Value<int?> was = const Value.absent(),
                Value<double?> rating = const Value.absent(),
                Value<int?> reviews = const Value.absent(),
                Value<bool> inStock = const Value.absent(),
                Value<String> query = const Value.absent(),
                required String seen,
                Value<String> dhash = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaOffersCompanion.insert(
                id: id,
                shop: shop,
                url: url,
                title: title,
                image: image,
                price: price,
                currency: currency,
                was: was,
                rating: rating,
                reviews: reviews,
                inStock: inStock,
                query: query,
                seen: seen,
                dhash: dhash,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaOffersTable, ShopOffer>(table),
                  BaseReferences<_$AppDatabase, $ChandaOffersTable, ShopOffer>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaOffersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaOffersTable,
      ShopOffer,
      $$ChandaOffersTableFilterComposer,
      $$ChandaOffersTableOrderingComposer,
      $$ChandaOffersTableAnnotationComposer,
      $$ChandaOffersTableCreateCompanionBuilder,
      $$ChandaOffersTableUpdateCompanionBuilder,
      (ShopOffer, BaseReferences<_$AppDatabase, $ChandaOffersTable, ShopOffer>),
      ShopOffer,
      PrefetchHooks Function()
    >;
typedef $$ChandaMatchesTableCreateCompanionBuilder = ChandaMatchesCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String itemId,
  required String url,
  required String verdict,
  Value<int> rowid,
});
typedef $$ChandaMatchesTableUpdateCompanionBuilder = ChandaMatchesCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> itemId,
  Value<String> url,
  Value<String> verdict,
  Value<int> rowid,
});

class $$ChandaMatchesTableFilterComposer extends Composer<_$AppDatabase, $ChandaMatchesTable> {
  $$ChandaMatchesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => ColumnFilters(column));
}

class $$ChandaMatchesTableOrderingComposer extends Composer<_$AppDatabase, $ChandaMatchesTable> {
  $$ChandaMatchesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get url =>
      $composableBuilder(column: $table.url, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => ColumnOrderings(column));
}

class $$ChandaMatchesTableAnnotationComposer extends Composer<_$AppDatabase, $ChandaMatchesTable> {
  $$ChandaMatchesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get url => $composableBuilder(column: $table.url, builder: (column) => column);

  GeneratedColumn<String> get verdict =>
      $composableBuilder(column: $table.verdict, builder: (column) => column);
}

class $$ChandaMatchesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChandaMatchesTable,
          ProductMatch,
          $$ChandaMatchesTableFilterComposer,
          $$ChandaMatchesTableOrderingComposer,
          $$ChandaMatchesTableAnnotationComposer,
          $$ChandaMatchesTableCreateCompanionBuilder,
          $$ChandaMatchesTableUpdateCompanionBuilder,
          (ProductMatch, BaseReferences<_$AppDatabase, $ChandaMatchesTable, ProductMatch>),
          ProductMatch,
          PrefetchHooks Function()
        > {
  $$ChandaMatchesTableTableManager(_$AppDatabase db, $ChandaMatchesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ChandaMatchesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ChandaMatchesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ChandaMatchesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> url = const Value.absent(),
                Value<String> verdict = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChandaMatchesCompanion(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                url: url,
                verdict: verdict,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> hlc = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required String itemId,
                required String url,
                required String verdict,
                Value<int> rowid = const Value.absent(),
              }) => ChandaMatchesCompanion.insert(
                id: id,
                hlc: hlc,
                deleted: deleted,
                itemId: itemId,
                url: url,
                verdict: verdict,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChandaMatchesTable, ProductMatch>(table),
                  BaseReferences<_$AppDatabase, $ChandaMatchesTable, ProductMatch>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChandaMatchesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChandaMatchesTable,
      ProductMatch,
      $$ChandaMatchesTableFilterComposer,
      $$ChandaMatchesTableOrderingComposer,
      $$ChandaMatchesTableAnnotationComposer,
      $$ChandaMatchesTableCreateCompanionBuilder,
      $$ChandaMatchesTableUpdateCompanionBuilder,
      (ProductMatch, BaseReferences<_$AppDatabase, $ChandaMatchesTable, ProductMatch>),
      ProductMatch,
      PrefetchHooks Function()
    >;
typedef $$PrefsTableCreateCompanionBuilder = PrefsCompanion Function({
  required String id,
  Value<String> hlc,
  Value<bool> deleted,
  required String value,
  Value<int> rowid,
});
typedef $$PrefsTableUpdateCompanionBuilder = PrefsCompanion Function({
  Value<String> id,
  Value<String> hlc,
  Value<bool> deleted,
  Value<String> value,
  Value<int> rowid,
});

class $$PrefsTableFilterComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$PrefsTableOrderingComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$PrefsTableAnnotationComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hlc => $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$PrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrefsTable,
          Pref,
          $$PrefsTableFilterComposer,
          $$PrefsTableOrderingComposer,
          $$PrefsTableAnnotationComposer,
          $$PrefsTableCreateCompanionBuilder,
          $$PrefsTableUpdateCompanionBuilder,
          (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
          Pref,
          PrefetchHooks Function()
        > {
  $$PrefsTableTableManager(_$AppDatabase db, $PrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> hlc = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PrefsCompanion(id: id, hlc: hlc, deleted: deleted, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String id,
            Value<String> hlc = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => PrefsCompanion.insert(id: id, hlc: hlc, deleted: deleted, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrefsTable, Pref>(table),
                  BaseReferences<_$AppDatabase, $PrefsTable, Pref>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrefsTable,
      Pref,
      $$PrefsTableFilterComposer,
      $$PrefsTableOrderingComposer,
      $$PrefsTableAnnotationComposer,
      $$PrefsTableCreateCompanionBuilder,
      $$PrefsTableUpdateCompanionBuilder,
      (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
      Pref,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder = OutboxCompanion Function({
  required String entity,
  required String rowId,
  Value<int?> seq,
  Value<int> rowid,
});
typedef $$OutboxTableUpdateCompanionBuilder = OutboxCompanion Function({
  Value<String> entity,
  Value<String> rowId,
  Value<int?> seq,
  Value<int> rowid,
});

class $$OutboxTableFilterComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $$OutboxTableOrderingComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $$OutboxTableAnnotationComposer extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get rowId => $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxItem,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxItem, BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>),
          OutboxItem,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> entity = const Value.absent(),
            Value<String> rowId = const Value.absent(),
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => OutboxCompanion(entity: entity, rowId: rowId, seq: seq, rowid: rowid),
          createCompanionCallback: ({
            required String entity,
            required String rowId,
            Value<int?> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => OutboxCompanion.insert(entity: entity, rowId: rowId, seq: seq, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$OutboxTable, OutboxItem>(table),
                  BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxItem,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxItem, BaseReferences<_$AppDatabase, $OutboxTable, OutboxItem>),
      OutboxItem,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder = SyncCursorsCompanion Function({
  required String deviceId,
  required int seq,
  Value<int> rowid,
});
typedef $$SyncCursorsTableUpdateCompanionBuilder = SyncCursorsCompanion Function({
  Value<String> deviceId,
  Value<int> seq,
  Value<int> rowid,
});

class $$SyncCursorsTableFilterComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $$SyncCursorsTableOrderingComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $$SyncCursorsTableAnnotationComposer extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get seq => $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> deviceId = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion(deviceId: deviceId, seq: seq, rowid: rowid),
          createCompanionCallback: ({
            required String deviceId,
            required int seq,
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion.insert(deviceId: deviceId, seq: seq, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (SyncCursor, BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$LocalSettingsTableCreateCompanionBuilder = LocalSettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$LocalSettingsTableUpdateCompanionBuilder = LocalSettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$LocalSettingsTableFilterComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$LocalSettingsTableOrderingComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$LocalSettingsTableAnnotationComposer extends Composer<_$AppDatabase, $LocalSettingsTable> {
  $$LocalSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSettingsTable,
          LocalSetting,
          $$LocalSettingsTableFilterComposer,
          $$LocalSettingsTableOrderingComposer,
          $$LocalSettingsTableAnnotationComposer,
          $$LocalSettingsTableCreateCompanionBuilder,
          $$LocalSettingsTableUpdateCompanionBuilder,
          (LocalSetting, BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>),
          LocalSetting,
          PrefetchHooks Function()
        > {
  $$LocalSettingsTableTableManager(_$AppDatabase db, $LocalSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => LocalSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => LocalSettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalSettingsTable, LocalSetting>(table),
                  BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSettingsTable,
      LocalSetting,
      $$LocalSettingsTableFilterComposer,
      $$LocalSettingsTableOrderingComposer,
      $$LocalSettingsTableAnnotationComposer,
      $$LocalSettingsTableCreateCompanionBuilder,
      $$LocalSettingsTableUpdateCompanionBuilder,
      (LocalSetting, BaseReferences<_$AppDatabase, $LocalSettingsTable, LocalSetting>),
      LocalSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChandaListsTableTableManager get chandaLists => $$ChandaListsTableTableManager(_db, _db.chandaLists);
  $$ChandaItemsTableTableManager get chandaItems => $$ChandaItemsTableTableManager(_db, _db.chandaItems);
  $$ChandaPricesTableTableManager get chandaPrices => $$ChandaPricesTableTableManager(_db, _db.chandaPrices);
  $$ChandaAlertsTableTableManager get chandaAlerts => $$ChandaAlertsTableTableManager(_db, _db.chandaAlerts);
  $$ChandaOffersTableTableManager get chandaOffers => $$ChandaOffersTableTableManager(_db, _db.chandaOffers);
  $$ChandaMatchesTableTableManager get chandaMatches =>
      $$ChandaMatchesTableTableManager(_db, _db.chandaMatches);
  $$PrefsTableTableManager get prefs => $$PrefsTableTableManager(_db, _db.prefs);
  $$OutboxTableTableManager get outbox => $$OutboxTableTableManager(_db, _db.outbox);
  $$SyncCursorsTableTableManager get syncCursors => $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$LocalSettingsTableTableManager get localSettings =>
      $$LocalSettingsTableTableManager(_db, _db.localSettings);
}
