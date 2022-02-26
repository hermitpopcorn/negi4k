part of '../database.dart';

enum AccountType {
  regular,
  noncurrent,
  sink,
}

class Accounts extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(min: 1, max: 32)();
  IntColumn get type => intEnum<AccountType>().withDefault(Constant(AccountType.regular.index))();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get order => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withLength(min: 1, max: 6).withDefault(const Constant('IDR'))();
  DateTimeColumn get createdAt => dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt => dateTime().clientDefault(() => DateTime.now())();
  
  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [Accounts, Transactions])
class AccountsDao extends DatabaseAccessor<Database> with _$AccountsDaoMixin {
  AccountsDao(Database db) : super(db);

  Future<List<Account>> get allAccounts => select(accounts).get();
  Stream<List<Account>> get watchAccounts => select(accounts).watch();

  Future<int> calculateBalance(Account a, {DateTime? from, DateTime? to}) async {
    // TODO: Time frame constraint

    if (a.type == AccountType.sink) { return 0; }
    int balance = a.initialBalance;

    final joinAccount = alias(accounts, 'a');
    final joinTarget = alias(accounts, 't');

    List<TypedResult> trxs = await (select(transactions)
      ..where((t) => (t.account.equals(a.id) | t.target.equals(a.id)))
    )
    .join([
      innerJoin(joinAccount, joinAccount.id.equalsExp(transactions.account)),
      leftOuterJoin(joinTarget, joinTarget.id.equalsExp(transactions.target)),
    ])
    .get();

    for(TypedResult trx in trxs) {
      final t = trx.readTable(transactions);
      if (t.account == a.id) {
        if (t.type == TransactionType.income) {
          balance += t.amount;
        } else if (t.type == TransactionType.expense) {
          balance -= t.amount;
        } else if (t.type == TransactionType.transfer) {
          balance -= t.amount;
        }
      } else {
        if (t.target == a.id && t.type == TransactionType.transfer) {
          balance += t.amountAfterExchange ?? t.amount;
        }
      }
    }

    return balance;
  }

  Future<Account> find(String id) => (select(accounts)..where((t) => t.id.equals(id))).getSingle();

  Future<Account> create({ required String name, AccountType? type, dynamic initialBalance, int? order, String? currency }) {
    int? intInitialBalance;
    if (initialBalance is int) {
      intInitialBalance = initialBalance;
    } else if (initialBalance is String) {
      intInitialBalance = (Decimal.parse(initialBalance) * Decimal.parse('100')).toBigInt().toInt();
    } else if (initialBalance == null) {
      intInitialBalance = null;
    } else {
      throw ArgumentError.value(initialBalance);
    }

    AccountsCompanion newAccount = AccountsCompanion(
      name: Value(name),
      type: type != null ? Value(type) : const Value.absent(),
      initialBalance: intInitialBalance != null ? Value(intInitialBalance) : const Value.absent(),
      order: order != null ? Value(order) : const Value.absent(),
      currency: currency != null ? Value(currency) : const Value.absent(),
    );
    return into(accounts).insertReturning(newAccount);
  }

  Future<int> edit(dynamic existingAccount, { required String name, AccountType? type, dynamic initialBalance, int? order, String? currency }) {
    String accountId;
    if (existingAccount is String) {
      accountId = existingAccount;
    } else if (existingAccount is Account) {
      accountId = existingAccount.id;
    } else {
      throw ArgumentError.value(existingAccount);
    }

    int? intInitialBalance;
    if (initialBalance is int) {
      intInitialBalance = initialBalance;
    } else if (initialBalance is String) {
      intInitialBalance = (Decimal.parse(initialBalance) * Decimal.parse('100')).toBigInt().toInt();
    } else if (initialBalance == null) {
      intInitialBalance = null;
    } else {
      throw ArgumentError.value(initialBalance);
    }

    AccountsCompanion updateValues = AccountsCompanion(
      name: Value(name),
      type: type != null ? Value(type) : const Value.absent(),
      initialBalance: intInitialBalance != null ? Value(intInitialBalance) : const Value.absent(),
      order: order != null ? Value(order) : const Value.absent(),
      currency: currency != null ? Value(currency) : const Value.absent(),
    );
    return (update(accounts)..where((t) => t.id.equals(accountId))).write(updateValues);
  }

  Future<int> remove(dynamic account) async {
    String? id;
    if (account is String) {
      id = account;
    } else if (account is Account) {
      id = account.id;
    } else {
      throw ArgumentError.value(account);
    }

    // Delete all income/expense transactions belonging to the accounts
    await (delete(transactions)..where((t) => t.account.equals(id) & t.type.isIn([TransactionType.income.index, TransactionType.expense.index]))).go();

    // Change transfers (outgoing into income)
    List<Transaction> transfers = await (select(transactions)..where((t) => t.type.equals(TransactionType.transfer.index) & t.account.equals(id))).get();
    for (Transaction transfer in transfers) {
      String newAccount = transfer.target!;
      int newAmount = transfer.amountAfterExchange ?? transfer.amount;
      await (update(transactions)..where((t) => t.id.equals(transfer.id))).write(TransactionsCompanion(
        type: const Value(TransactionType.income),
        account: Value(newAccount),
        target: const Value(null),
        amount: Value(newAmount),
        amountAfterExchange: const Value(null),
      ));
    }

    // Change transfers (incoming into expense)
    transfers = await (select(transactions)..where((t) => t.type.equals(TransactionType.transfer.index) & t.target.equals(id))).get();
    for (Transaction transfer in transfers) {
      await (update(transactions)..where((t) => t.id.equals(transfer.id))).write(const TransactionsCompanion(
        type: Value(TransactionType.expense),
        target: Value(null),
        amountAfterExchange: Value(null),
      ));
    }

    return (delete(accounts)..where((t) => t.id.equals(id))).go();
  }
}