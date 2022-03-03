part of '../main.dart';

class AccountsForm extends HookWidget {
  final Account? account;
  AccountsForm({Key? key, this.account}) : super(key: key);
  
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final processingState = useState(false);
    final nameState = useTextEditingController(text: '');
    final typeState = useState(AccountType.regular);
    final initialBalanceState = useTextEditingController(text: '');
    final currencyState = useTextEditingController(text: '');
    final orderState = useTextEditingController(text: '');

    useEffect(() {
      if (account == null) return;
      typeState.value = account!.type;
      nameState.text = account!.name;
      initialBalanceState.text = decimalizeAmount(account!.initialBalance);
      currencyState.text = account!.currency;
      orderState.text = account!.order.toString();
      
      return;
    }, [account]);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Account"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                TextFormField(
                  controller: nameState,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Name"),
                    alignLabelWithHint: true,
                  ),
                ),
                DropdownButtonFormField<AccountType>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Type"),
                  ),
                  value: typeState.value,
                  elevation: 4,
                  onChanged: (newValue) {
                    if (newValue != null) typeState.value = newValue;
                  },
                  items: AccountType.values.map<DropdownMenuItem<AccountType>>(
                    (AccountType at) => DropdownMenuItem<AccountType>(
                      value: at,
                      child: Row(
                        children: [
                          accountIcons[at] ?? const SizedBox.shrink(),
                          const SizedBox(width: 8),
                          Text(accountTypeNames[at] ?? '?'),
                        ],
                      ),
                    )
                  ).toList(),
                  validator: (value) {
                    if (value == null) return "Account type is required.";
                    return null;
                  },
                ),
                Focus(
                  child: TextFormField(
                    controller: currencyState,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: Text("Currency"),
                      alignLabelWithHint: true,
                    ),
                    validator: (newValue) {
                      if (newValue != null && newValue.length > 6) return "Maximum 6 characters long.";
                      return null;
                    },
                  ),
                  onFocusChange: (hasFocus) {
                    String text = currencyState.value.text;
                    if (text.length > 6) text = text.substring(0, 6);
                    text = text.toUpperCase();
                    currencyState.value = TextEditingValue(text: text);
                  },
                ),
                TextFormField(
                  controller: initialBalanceState,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Initial balance"),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;

                    final validDecimal = RegExp(r"^([0-9]+)?(\.[0-9][0-9]?)?$");
                    if (validDecimal.hasMatch(value) == false) {
                      return 'Invalid format.';
                    }

                    return null;
                  },
                ),
                TextFormField(
                  controller: orderState,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                  ],
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: false),
                  autocorrect: false,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Order"),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;

                    final validDecimal = RegExp(r"^([0-9]+)$");
                    if (validDecimal.hasMatch(value) == false) {
                      return 'Invalid number.';
                    }

                    return null;
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () async {
                        if (processingState.value == true) return;
                        if (_formKey.currentState!.validate() == false) return;

                        processingState.value = true;

                        Account? editedObject;
                        if (account == null) {
                          editedObject = await getit<DataSource>().accountsDao.create(
                            type: typeState.value,
                            name: nameState.value.text,
                            initialBalance: initialBalanceState.value.text.isNotEmpty ? initialBalanceState.value.text : null,
                            currency: currencyState.value.text.isNotEmpty ? currencyState.value.text : null,
                            order: orderState.value.text.isNotEmpty ? int.parse(orderState.value.text) : null,
                          );
                        } else {
                          await getit<DataSource>().accountsDao.edit(
                            account,
                            type: typeState.value,
                            name: nameState.value.text,
                            initialBalance: initialBalanceState.value.text.isNotEmpty ? initialBalanceState.value.text : null,
                            currency: currencyState.value.text.isNotEmpty ? currencyState.value.text : null,
                            order: orderState.value.text.isNotEmpty ? int.parse(orderState.value.text) : null,
                          );
                          editedObject = await getit<DataSource>().accountsDao.find(account!.id);
                        }

                        processingState.value = false;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Account saved.'), backgroundColor: Colors.green[700]!, duration: const Duration(seconds: 2)),
                        );

                        Navigator.of(context).pop(editedObject);
                      },
                      child: processingState.value ? const SpinKitThreeBounce(color: Colors.white, size: 24) : const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
