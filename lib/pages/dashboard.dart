part of '../main.dart';

class DashboardPage extends HookWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final refresher = useState<int>(0);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // TODO: Monthly balance display

              // Account balances
              StreamBuilder(
                stream: getit<DataSource>().accountsDao.watchAccounts,
                builder: (BuildContext context, AsyncSnapshot<List<Account>> snapshot) {
                  if (snapshot.data != null) {
                    return buildAccountBalances(snapshot.data!);
                  }
                  return SpinKitThreeBounce(color: Colors.grey[400]!);
                }
              ),
              // Refresh
              Container(
                alignment: Alignment.topRight,
                child: ElevatedButton(
                  child: const Icon(Icons.refresh_rounded),
                  onPressed: () { refresher.value += 1; },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAccountBalances(List<Account> accounts) {
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
              if (balance.data != null) return displayAmountWidget(balance.data!, currency: account.currency);
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

      return ListView(scrollDirection: Axis.vertical, shrinkWrap: true, children: children);
    }
  }
}