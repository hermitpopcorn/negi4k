import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart';
import 'dart:io';
import 'dart:collection';
import 'package:uuid/uuid.dart';
import 'package:decimal/decimal.dart';

part 'tables/accounts.dart';
part 'tables/transactions.dart';
part 'database.g.dart';

const uuid = Uuid();

abstract class DataSource {
  // Just a tag for dependency injector
  late final AccountsDao accountsDao;
  late final TransactionsDao transactionsDao;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}

@DriftDatabase(tables: [Accounts, Transactions], daos: [AccountsDao, TransactionsDao])
class Database extends _$Database implements DataSource {
  Database() : super(_openConnection());

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (OpeningDetails details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
    onCreate: (Migrator migrator) async {
      migrator.createTable(accounts);
      migrator.createTable(transactions);
      await accountsDao.create(
        name: 'Bank',
      );
      await accountsDao.create(
        name: 'Wallet',
        type: AccountType.sink,
      );
    },
  );

  @override
  int get schemaVersion => 1;

  @override
  set accountsDao(AccountsDao? _accountsDao) => AccountsDao(this);
  @override
  set transactionsDao(TransactionsDao? _transactionsDao) => TransactionsDao(this);
}
