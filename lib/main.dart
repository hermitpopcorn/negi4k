import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get_it/get_it.dart';
import 'package:styled_widget/styled_widget.dart';
import 'package:material_segmented_control/material_segmented_control.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import 'database.dart';
import 'helpers.dart';

part 'pages/dashboard.dart';
part 'pages/transactions.dart';
part 'pages/transactions_form.dart';
part 'pages/accounts.dart';
part 'pages/accounts_form.dart';

enum AppTabs {
  dashboard,
  transactions,
  accounts,
}

final Map<AccountType, Color> accountColors = {
  AccountType.regular: Colors.green[200]!,
  AccountType.sink: Colors.red[200]!,
  AccountType.noncurrent: Colors.blue[200]!,
};

final Map<AccountType, Icon> accountIcons = {
  AccountType.regular: const Icon(Icons.credit_card_rounded),
  AccountType.sink: const Icon(Icons.account_balance_wallet_rounded),
  AccountType.noncurrent: const Icon(Icons.ac_unit_rounded),
};

final Map<AccountType, String> accountTypeNames = {
  AccountType.regular: "Regular",
  AccountType.sink: "Sink",
  AccountType.noncurrent: "Non-current",
};

final getit = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  getit.registerSingleton<DataSource>(Database());
  runApp(const Negi4k());
}

class Negi4k extends StatelessWidget {
  const Negi4k({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'negi4k',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const App(title: 'negi4k'),
    );
  }
}

class App extends HookWidget {
  const App({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    final currentTab = useState(AppTabs.dashboard);      

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Offstage(
            offstage: currentTab.value != AppTabs.dashboard,
            child: const DashboardPage(),
          ),
          Offstage(
            offstage: currentTab.value != AppTabs.transactions,
            child: const TransactionsPage(),
          ),
          Offstage(
            offstage: currentTab.value != AppTabs.accounts,
            child: const AccountsPage(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigation(currentTab: currentTab),
  );
  }
}

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({Key? key, required this.currentTab}) : super(key: key);

  final ValueNotifier<AppTabs> currentTab;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentTab.value.index,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.space_dashboard_rounded),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.compare_arrows_rounded),
          label: "",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.storage_rounded),
          label: "",
        ),
      ],
      onTap: (index) => currentTab.value = AppTabs.values[index],
    );
  }
}
