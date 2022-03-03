part of '../main.dart';

class TransactionsPage extends HookWidget {
  const TransactionsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final year = useState<int>(DateTime.now().year);
    final month = useState<int>(DateTime.now().month);

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Month selector
            Card(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_left_rounded),
                      splashRadius: 20,
                      tooltip: 'Previous month',
                      onPressed: () {
                        DateTime dt = DateTime(year.value, month.value - 1, 1);
                        year.value = dt.year;
                        month.value = dt.month;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text("${year.value.toString().padLeft(2, '0')} ${month.value.toString().padLeft(2, '0')}", textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_right_rounded),
                      splashRadius: 20,
                      tooltip: 'Next month',
                      onPressed: () {
                        DateTime dt = DateTime(year.value, month.value + 1, 1);
                        year.value = dt.year;
                        month.value = dt.month;
                      },
                    ),
                  ),
                ],
              ),
            ).padding(vertical: 12, horizontal: 8),

            // Transactions list
            StreamBuilder(
              stream: getit<DataSource>().transactionsDao.watchTransactionsBetween(getMonthStart(year.value, month.value), getMonthEnd(year.value, month.value)),
              builder: (BuildContext context, AsyncSnapshot<List<TransactionWithAccounts>> snapshot) {
                if (snapshot.data != null) {
                  return buildTransactionList(snapshot.data!);
                }
                return SpinKitThreeBounce(color: Colors.grey[400]!);
              }
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            const SizedBox(width: 10),
            FloatingActionButton(
              onPressed: () { openForm(context); },
              tooltip: 'Add',
              heroTag: 'btnAddTransaction',
              child: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTransactionList(List<TransactionWithAccounts> transactions) {
    if (transactions.isEmpty) {
      return Center(
        child: Icon(Icons.more_horiz_rounded, size: 86, color: Colors.grey[300]!),
      );
    } else {
      Map<TransactionType, Color> transactionColors = {
        TransactionType.income: Colors.green[200]!,
        TransactionType.expense: Colors.red[200]!,
        TransactionType.transfer: Colors.purple[200]!,
      };
      Map<TransactionType, Icon> transactionIcons = {
        TransactionType.income: const Icon(Icons.trending_up_rounded),
        TransactionType.expense: const Icon(Icons.trending_down_rounded),
        TransactionType.transfer: const Icon(Icons.sync_rounded),
      };

      List<Widget> children = [];
      DateTime? currentDate;
      for (int i = 0; i < transactions.length; i++) {
        final TransactionWithAccounts t = transactions[i];

        bool drawDate = false;
        if (currentDate != DateTime(t.transaction.timestamp.year, t.transaction.timestamp.month, t.transaction.timestamp.day)) {
          currentDate = DateTime(t.transaction.timestamp.year, t.transaction.timestamp.month, t.transaction.timestamp.day);
          drawDate = true;
        }

        Wrap amount = displayAmountWidget(t.transaction.amount, currency: t.account.currency);
        Wrap? amountAfterExchange = t.transaction.amountAfterExchange != null && t.target != null ? displayAmountWidget(t.transaction.amountAfterExchange!, currency: t.target!.currency) : null;
        String subtitle = t.account.name;
        if (t.target != null) {
          subtitle += " -> ${t.target!.name}";
        }

        // Date
        if (drawDate) {
          children.add(
            Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      color: Colors.grey[200]!,
                      height: 2,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(formatDate(currentDate!)),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.grey[200]!,
                      height: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Slidable transaction item
        children.add(
          Slidable(
            key: UniqueKey(),
            startActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) { deleteTransaction(context, t.transaction); },
                  backgroundColor: Colors.red[300]!,
                  foregroundColor: Colors.white,
                  icon: Icons.delete_rounded,
                  label: 'Delete',
                ),
              ],
            ),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) { openForm(context, t.transaction); },
                  backgroundColor: Colors.teal[300]!,
                  foregroundColor: Colors.white,
                  icon: Icons.edit_rounded,
                  label: 'Edit',
                ),
              ],
            ),

            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.rectangle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 2,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left color
                    // Timestamp
                    RotatedBox(
                      quarterTurns: 3,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 1, 8, 0),
                        child: Text(formatTime(t.transaction.timestamp), textAlign: TextAlign.end, style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        )),
                      ),
                    ).width(14).backgroundColor(transactionColors[t.transaction.type]!),
                    // Center content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Amount and account
                        ListTile(
                          leading: accountIcons[t.account.type],
                          trailing: transactionIcons[t.transaction.type],
                          title: Wrap(
                            children: [
                              amount,
                              if (amountAfterExchange != null) const Text(' > '),
                              if (amountAfterExchange != null) amountAfterExchange,
                            ],
                          ),
                          subtitle: Text(subtitle),
                        ),
                        if (t.transaction.note != null) Text(t.transaction.note!).padding(left: 16, right: 16, bottom: t.transaction.tags == null ? 16 : 0),
                        if (t.transaction.tags != null) Wrap(spacing: 4, runSpacing: 4, children: t.transaction.tags!.split(' ').map<Widget>(
                          (tag) => TextButton(
                            onPressed: () {  },
                            child: Text("#$tag", style: TextStyle(color: Colors.blue[800]!)),
                            style: ButtonStyle(minimumSize: MaterialStateProperty.all(Size.zero)),
                          ),
                        ).toList()).padding(left: 16, right: 6)
                      ],
                    ).expanded(),
                    // Right color
                    Container(
                      width: 14,
                      color: transactionColors[t.determineImpact()],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        children.add(const SizedBox(height: 4));
      }

      return ListView(physics: const ClampingScrollPhysics(), scrollDirection: Axis.vertical, shrinkWrap: true, children: children);
    }
  }

  void openForm(BuildContext context, [Transaction? transaction]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => TransactionsForm(transaction: transaction))).then((dynamic t) {
      if (t is Transaction) {
        // TODO: show transaction
      }
    });
  }

  Future<void> deleteTransaction(context, Transaction transaction) async {
    await getit<DataSource>().transactionsDao.remove(transaction);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text('Transaction deleted.'), backgroundColor: Colors.red[700]!, duration: const Duration(seconds: 2)),
    );
  }
}
