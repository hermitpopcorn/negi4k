part of '../main.dart';

class AccountsPage extends HookWidget {
  const AccountsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Accounts"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Add account',
            onPressed: () { openForm(context); },
            splashRadius: 20,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              // Accounts
              StreamBuilder(
                stream: getit<DataSource>().accountsDao.watchAccounts,
                builder: (BuildContext context, AsyncSnapshot<List<Account>> snapshot) {
                  if (snapshot.data != null) {
                    return buildAccountCards(context, snapshot.data!);
                  }
                  return SpinKitThreeBounce(color: Colors.grey[400]!);
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAccountCards(BuildContext context, List<Account> accounts) {
    if (accounts.isEmpty) {
      return const Center(
        child: Text(
          'No accounts saved.',
        ),
      );
    } else {
      List<Card> children = [];
      for (Account account in accounts) {
        children.add(Card(
          color: accountColors[account.type],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ListTile(
                leading: accountIcons[account.type],
                title: Text(account.name),
                subtitle: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Wrap(
                      children: [const Text('Initial balance: '), displayAmountWidget(account.initialBalance, currency: account.currency)],
                    ),
                  ],
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      splashRadius: 20,
                      tooltip: 'Edit',
                      onPressed: () { openForm(context, account); },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded),
                      splashRadius: 20,
                      tooltip: 'Delete',
                      onPressed: () { deleteAccount(context, account); },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
      }

      return ListView(scrollDirection: Axis.vertical, shrinkWrap: true, children: children);
    }
  }

  void openForm(BuildContext context, [Account? account]) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => AccountsForm(account: account)));
  }

  void deleteAccount(BuildContext context, Account? account) {
    showDialog(context: context, builder: (BuildContext builder) => AlertDialog(
      title: const Text("Confirm Delete"),
      content: const Text("Are you sure? Transactions concerning this account will be deleted or changed."),
      actions: [
        TextButton(child: const Text("Cancel"), onPressed: () { Navigator.pop(context, false); }),
        ElevatedButton(
          child: const Text('Delete'),
          style: ButtonStyle(backgroundColor: MaterialStateProperty.all(Colors.red[400]!)),
          onPressed: () async {
            await getit<DataSource>().accountsDao.remove(account);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text('Account deleted.'), backgroundColor: Colors.red[700]!, duration: const Duration(seconds: 2)),
            );
            Navigator.pop(context, false);
          },
        ),
      ]
    ));
  }
}