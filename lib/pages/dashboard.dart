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
          currencyStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          numberStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          decimalStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        );
        cbw.add(w);
      });

      currencyBalancesWidget.value = cbw;
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Refresh
          Container(
            alignment: Alignment.topRight,
            child: ElevatedButton(
              child: const Icon(Icons.refresh_rounded),
              onPressed: () { accountsRefresher.value += 1; },
              style: ElevatedButton.styleFrom(fixedSize: Size(10, 10)),
            ),
          ),
          // Current balance
          Card(
            child: Column(
              children: [
                const Text("Current balance", textAlign: TextAlign.center).width(double.infinity),
                Wrap(
                  spacing: 24,
                  direction: Axis.horizontal,
                  alignment: WrapAlignment.spaceAround,
                  children: currencyBalancesWidget.value,
                ),
              ]
            ).padding(vertical: 12, horizontal: 12),
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
    );
  }

  Widget buildAccountBalances(List<Account> accounts, ValueNotifier<Map<Account, int>> accountBalancesState, Function recalculator) {
    if (accounts.isEmpty) {
      return const Center(
        child: Text(
          'No accounts saved.',
        ),
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