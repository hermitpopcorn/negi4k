part of '../database.dart';

enum TransactionType {
  income,
  expense,
  transfer,
}

class Transactions extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();
  IntColumn get type => intEnum<TransactionType>().withDefault(Constant(TransactionType.income.index))();
  TextColumn get account => text().customConstraint('REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT')();
  TextColumn get target => text().nullable().customConstraint('NULL REFERENCES accounts(id) ON UPDATE CASCADE ON DELETE RESTRICT')();
  IntColumn get amount => integer().withDefault(const Constant(0))();
  IntColumn get amountAfterExchange => integer().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get timestamp => dateTime().clientDefault(() => DateTime.now())();
  TextColumn get tags => text().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();

  @override
  Set<Column> get primaryKey => {id};
}

class TransactionWithAccounts {
  final Transaction transaction;
  final Account account;
  Account? target;

  TransactionWithAccounts({
    required this.transaction,
    required this.account,
    this.target,
  });

  TransactionType determineImpact() {
    // Just straight up return type if not transfer
    if (transaction.type != TransactionType.transfer) return transaction.type;

    // Throw error if transfer has no target
    if (target == null) throw Error();

    bool sinkSource = account.type == AccountType.sink;
    bool sinkDestination = target!.type == AccountType.sink;

    // If account types are both non-sink
    if (!sinkSource && !sinkDestination) {
      // If exchange rates aren't involved, return as transfer
      if (transaction.amountAfterExchange == null || transaction.amountAfterExchange == transaction.amount) return TransactionType.transfer;

      // If currencies are different, return as transfer
      if (account.currency != target!.currency) return TransactionType.transfer;

      // Determine by how many lost / gained
      if (transaction.amountAfterExchange! > transaction.amount) return TransactionType.income;
      if (transaction.amountAfterExchange! < transaction.amount) return TransactionType.expense;
    }
    // If account types are both sink
    else if (sinkSource && sinkDestination) {
      return TransactionType.transfer;
    }
    // If account types are sink and non-sink
    else {
      // Regular -> Sink = Expense
      if (!sinkSource && sinkDestination) return TransactionType.expense;
      // Sink -> Regular = Income
      if (sinkSource && !sinkDestination) return TransactionType.income;
    }

    // Throw error if no match
    throw Error();
  }
}

@DriftAccessor(tables: [Transactions, Accounts])
class TransactionsDao extends DatabaseAccessor<Database> with _$TransactionsDaoMixin {
  TransactionsDao(Database db) : super(db);

  Future<Transaction> find(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingle();
  }
  
  Stream<List<TransactionWithAccounts>> watchTransactionsBetween(DateTime from, DateTime to) {
    final joinAccount = alias(accounts, 'a');
    final joinTarget = alias(accounts, 't');

    return (select(transactions)
      ..where((t) => t.timestamp.isBetweenValues(from, to))
      ..orderBy([
        (t) => OrderingTerm.desc(t.timestamp)
      ])
    )
    .join([
      innerJoin(joinAccount, joinAccount.id.equalsExp(transactions.account)),
      leftOuterJoin(joinTarget, joinTarget.id.equalsExp(transactions.target)),
    ])
    .watch()
    .map((result) =>
      result.map((row) =>
        TransactionWithAccounts(
          transaction: row.readTable(transactions),
          account: row.readTable(joinAccount),
          target: row.readTableOrNull(joinTarget)
        )
      ).toList()
    );
  }

  Future<List<int>> calculateIncomeExpense(DateTime? from, DateTime? to) async {
    final joinAccount = alias(accounts, 'a');
    final joinTarget = alias(accounts, 't');

    SimpleSelectStatement<$TransactionsTable, Transaction> query = select(transactions)
      ..orderBy([
        (t) => OrderingTerm.desc(t.timestamp)
      ])
    ;
    if (from != null) query = query..where((t) => t.timestamp.isBiggerOrEqualValue(from));
    if (to != null) query = query..where((t) => t.timestamp.isSmallerOrEqualValue(to));

    final trxs = (await query
    .join([
      innerJoin(joinAccount, joinAccount.id.equalsExp(transactions.account)),
      leftOuterJoin(joinTarget, joinTarget.id.equalsExp(transactions.target)),
    ])
    .get())
    .map((row) =>
      TransactionWithAccounts(
        transaction: row.readTable(transactions),
        account: row.readTable(joinAccount),
        target: row.readTableOrNull(joinTarget)
      )
    );

    int income = 0;
    int expense = 0;
    for (TransactionWithAccounts trx in trxs) {
      switch(trx.transaction.type) {
        case TransactionType.income:
          income += trx.transaction.amount;
          break;
        case TransactionType.expense:
          expense += trx.transaction.amount;
          break;
        case TransactionType.transfer:
          if (trx.determineImpact() == TransactionType.income) income += (trx.transaction.amountAfterExchange! - trx.transaction.amount).abs();
          if (trx.determineImpact() == TransactionType.income) expense += (trx.transaction.amount - trx.transaction.amountAfterExchange!).abs();
          break;
      }
    }

    return [income, expense];
  }

  TransactionsCompanion prepareCompanion({
    required TransactionType type, required dynamic account, dynamic target,
    required String amount, String? amountAfterExchange, String? note, String? timestamp, String? tags,
  }) {
    String accountId;
    if (account is String) {
      accountId = account;
    } else if (account is Account) {
      accountId = account.id;
    } else {
      throw ArgumentError.value(account);
    }

    String? targetId;
    if (target is String) {
      targetId = target;
    } else if (target is Account) {
      targetId = target.id;
    } else {
      targetId = null;
    }

    int intAmount = (Decimal.parse(amount) * Decimal.parse('100')).toBigInt().toInt();
    int? intAmountAfterExchange = amountAfterExchange != null ? (Decimal.parse(amountAfterExchange) * Decimal.parse('100')).toBigInt().toInt() : null;

    DateTime dtTimestamp = timestamp != null ? DateTime.parse(timestamp) : DateTime.now();

    if (tags != null) tags = tags.trim();

    return TransactionsCompanion(
      type: Value(type),
      account: Value(accountId),
      target: targetId != null ? Value(targetId) : const Value.absent(),
      amount: Value(intAmount),
      amountAfterExchange: amountAfterExchange != null ? Value(intAmountAfterExchange) : const Value.absent(),
      note: note != null ? Value(note) : const Value.absent(),
      timestamp: timestamp != null ? Value(dtTimestamp) : const Value.absent(),
      tags: tags != null ? Value(tags) : const Value.absent(),
    );
  }

  Future<Transaction>? create({
    required TransactionType type, required dynamic account, dynamic target,
    required String amount, String? amountAfterExchange, String? note, String? timestamp, String? tags,
  }) {
    TransactionsCompanion newValues = prepareCompanion(type: type, account: account, target: target, amount: amount, amountAfterExchange: amountAfterExchange, note: note, timestamp: timestamp, tags: tags);
    return into(transactions).insertReturning(newValues);
  }

  Future<int>? edit(dynamic existingTransaction, {required TransactionType type, required dynamic account, dynamic target,
    required String amount, String? amountAfterExchange, String? note, String? timestamp, String? tags,
  }) {
    String transactionId;
    if (existingTransaction is String) {
      transactionId = existingTransaction;
    } else if (existingTransaction is Transaction) {
      transactionId = existingTransaction.id;
    } else {
      throw ArgumentError.value(existingTransaction);
    }

    TransactionsCompanion updateValues = prepareCompanion(type: type, account: account, target: target, amount: amount, amountAfterExchange: amountAfterExchange, note: note, timestamp: timestamp, tags: tags);
    return (update(transactions)..where((t) => t.id.equals(transactionId))).write(updateValues);
  }

  Future<int> remove(dynamic transaction) {
    String? id;
    if (transaction is String) {
      id = transaction;
    } else if (transaction is Transaction) {
      id = transaction.id;
    } else {
      throw ArgumentError.value(transaction);
    }

    return (delete(transactions)..where((t) => t.id.equals(id))).go();
  }
}
