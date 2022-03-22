part of '../main.dart';

class AccountWithBalance {
  final Account account;
  final int balance;

  AccountWithBalance({
    required this.account,
    required this.balance,
  });
}

class DashboardPage extends HookWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final accountsRefresher = useState<int>(0);

    final accountBalances = useState<Map<Account, int>>({});
    final currencyBalancesWidget = useState<List<Widget>>([]);
    
    void recalculateBalances() {
      Map<String, int> cb = {};

      accountBalances.value.forEach((a, b) {
        if (a.type != AccountType.regular) return;
        cb[a.currency] = (cb[a.currency] ?? 0) + b;
      });

      List<Widget> cbw = [];
      cb.forEach((c, b) {
        Widget w = displayAmountWidget(b, currency: c,
          currencyStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          numberStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          decimalStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        );
        cbw.add(w);
      });

      currencyBalancesWidget.value = cbw;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () { accountsRefresher.value += 1; },
            splashRadius: 20,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[ 
            // Current balance
            if (currencyBalancesWidget.value.isNotEmpty)
            Card(
              child: Column(
                children: [
                  const Text("Current balance", textAlign: TextAlign.center).width(double.infinity).padding(bottom: 4),
                  Wrap(
                    spacing: 24,
                    direction: Axis.horizontal,
                    alignment: WrapAlignment.spaceAround,
                    children: currencyBalancesWidget.value,
                  )
                ]
              ).padding(vertical: 12, horizontal: 12),
            ),

            // Current balance
            FutureBuilder(
              future: getit<DataSource>().transactionsDao.calculateIncomeExpense(getMonthStart(DateTime.now().year, DateTime.now().month), getMonthEnd(DateTime.now().year, DateTime.now().month)),
              builder: (builder, AsyncSnapshot<Map<String, List<int>>> snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                if (snapshot.data!.isEmpty) return const SizedBox.shrink();
                return Card(
                  child: Column(
                    children: [
                      const Text("This month's income/expense", textAlign: TextAlign.center).width(double.infinity).padding(bottom: 4),
                      Column(
                        children: buildIncomeExpenseRows(snapshot.data!),
                      ),
                    ],
                  ).padding(vertical: 12, horizontal: 12),
                );
              }
            ),

            // Account balances
            StreamBuilder(
              stream: getit<DataSource>().accountsDao.watchAccounts,
              builder: (BuildContext context, AsyncSnapshot<List<Account>> snapshot) {
                if (snapshot.data != null) {
                  return buildAccountBalances(snapshot.data!, accountBalances, recalculateBalances);
                }
                return SpinKitThreeBounce(color: Colors.grey[400]!);
              }
            ),
          ],
        ).padding(vertical: 12, horizontal: 8),
      )
    );
  }

  List<Widget> buildIncomeExpenseRows(Map<String, List<int>> data) {
    List<Widget> rows = [];
    data.forEach((String currency, List<int> incomeExpenseAmount) {
      rows.add(
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(6)),
          child: LinearProgressIndicator(
            backgroundColor: Colors.red[300]!,
            color: Colors.green[300]!,
            value: incomeExpenseAmount[0] / incomeExpenseAmount[1],
            minHeight: 6,
          ),
        ).padding(horizontal: 4)
      );

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            displayAmountWidget(incomeExpenseAmount[0], currency: currency),
            displayAmountWidget(incomeExpenseAmount[1], currency: currency),
          ],
        ).padding(horizontal: 4, vertical: 6)
      );
    });
    return rows;
  }

  Widget buildAccountBalances(List<Account> accounts, ValueNotifier<Map<Account, int>> accountBalancesState, Function recalculator) {
    if (accounts.isEmpty) {
      return Center(
        child: const Text(
          'No accounts saved.',
        ).padding(all: 24),
      );
    } else {
      List<Card> children = [];
      for (Account account in accounts) {
        FutureBuilder<int>? balanceText;
        if (account.type != AccountType.sink) {
          balanceText = FutureBuilder(
            future: getit<DataSource>().accountsDao.calculateBalance(account),
            builder: (BuildContext build, AsyncSnapshot<int> balance) {
              if (balance.hasData) {
                if (accountBalancesState.value[account] != balance.data) {
                  accountBalancesState.value[account] = balance.data!;
                  Future.delayed(Duration.zero, () { recalculator(); });
                }
                return displayAmountWidget(balance.data!, currency: account.currency);
              }
              return const Text("Calculating balance...");
            },
          );
        }

        children.add(Card(
          color: accountColors[account.type],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ListTile(
                leading: accountIcons[account.type],
                title: Text(account.name),
                subtitle: balanceText ?? const Text(''),
              ),
            ],
          ),
        ));
      }

      return ListView(physics: const ClampingScrollPhysics(), scrollDirection: Axis.vertical, shrinkWrap: true, children: children);
    }
  }
}