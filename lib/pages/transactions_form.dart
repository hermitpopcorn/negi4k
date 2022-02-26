part of '../main.dart';

class TransactionsForm extends HookWidget {
  final Transaction? transaction;
  TransactionsForm({Key? key, this.transaction}) : super(key: key);
  
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final accounts = useFuture(getit<DataSource>().accountsDao.allAccounts);
    final processingState = useState(false);
    final typeState = useState(TransactionType.income);
    final accountState = useState<Account?>(null);
    final targetState = useState<Account?>(null);
    final amountState = useTextEditingController(text: '');
    final amountAfterExchangeState = useTextEditingController(text: '');
    final noteState = useTextEditingController(text: '');
    final timestampState = useTextEditingController(text: '');
    final tagsState = useTextEditingController(text: '');

    useEffect(() {
      if (transaction == null) return;
      typeState.value = transaction!.type;
      () async {
        accountState.value = await getit<DataSource>().accountsDao.find(transaction!.account);
        if (transaction!.target != null) targetState.value = await getit<DataSource>().accountsDao.find(transaction!.target!);
      }();
      amountState.text = decimalizeAmount(transaction!.amount);
      amountAfterExchangeState.text = transaction!.amountAfterExchange != null ? decimalizeAmount(transaction!.amountAfterExchange!) : '';
      noteState.text = transaction!.note != null ? transaction!.note! : '';
      timestampState.text = formatDateTime(transaction!.timestamp);
      tagsState.text = transaction!.tags != null ? transaction!.tags! : '';
      
      return;
    }, [transaction]);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Transaction"),
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
                SizedBox(
                  width: double.infinity,
                  child: MaterialSegmentedControl(
                    children: const {
                      TransactionType.income: Text('Income'),
                      TransactionType.expense: Text('Expense'),
                      TransactionType.transfer: Text('Transfer'),
                    },
                    selectionIndex: typeState.value,
                    borderColor: Colors.grey[300],
                    selectedColor: {
                      TransactionType.income: Colors.green[400],
                      TransactionType.expense: Colors.red[400],
                      TransactionType.transfer: Colors.purple[400],
                    }[typeState.value]!,
                    unselectedColor: Colors.grey[50],
                    borderRadius: 8,
                    onSegmentChosen: (TransactionType newType) => typeState.value = newType,
                  ),
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Account"),
                  ),
                  value: accountState.value?.id,
                  elevation: 4,
                  onChanged: (newValue) {
                    final newAccount = accounts.data?.firstWhere((i) => i.id == newValue);
                    if (newAccount == null) return;
                    if(targetState.value == newAccount) targetState.value = null;
                    accountState.value = newAccount;
                  },
                  items: accounts.data?.map<DropdownMenuItem<String>>(
                    (Account a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Row(
                        children: [
                          accountIcons[a.type] ?? const SizedBox.shrink(),
                          const SizedBox(width: 8),
                          Text(a.name),
                        ],
                      ),
                    )
                  ).toList(),
                  validator: (value) {
                    if (value == null) return "Account is required.";
                    return null;
                  },
                ),
                if (typeState.value == TransactionType.transfer) ...[
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: Text("Target"),
                    ),
                    value: targetState.value?.id,
                    elevation: 4,
                    onChanged: (newValue) => targetState.value = accounts.data?.firstWhere((i) => i.id == newValue),
                    items: accounts.data?.where((Account a) => a.id != accountState.value?.id).map<DropdownMenuItem<String>>(
                      (Account a) => DropdownMenuItem<String>(
                        value: a.id,
                        child: Row(
                          children: [
                            accountIcons[a.type] ?? const SizedBox.shrink(),
                            const SizedBox(width: 8),
                            Text(a.name),
                          ],
                        ),
                      )
                    ).toList(),
                    validator: (value) {
                      if (typeState.value != TransactionType.transfer) return null;
                      if (value == null) return "Target account is required.";
                      return null;
                    },
                  ),
                ],
                TextFormField(
                  controller: amountState,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                  autocorrect: false,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    label: const Text("Amount"),
                    prefixText: <String>() {
                      if (accountState.value != null) {
                        return (accountState.value?.currency)! + " ";
                      }
                      return null;
                    }(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) { return 'Amount is required.'; }

                    final validDecimal = RegExp(r"^([0-9]+)?(\.[0-9][0-9]?)?$");
                    if (validDecimal.hasMatch(value) == false) {
                      return 'Invalid format.';
                    }

                    return null;
                  },
                ),
                if (typeState.value == TransactionType.transfer) ...[
                  TextFormField(
                    controller: amountAfterExchangeState,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    keyboardType: const TextInputType.numberWithOptions(signed: false, decimal: true),
                    autocorrect: false,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      label: const Text("Amount after exchange"),
                      prefixText: <String>() {
                        if (targetState.value != null) {
                          return (targetState.value?.currency)! + " ";
                        }
                        return null;
                      }(),
                    ),
                    validator: (value) {
                      if (value == null) return null;

                      final validDecimal = RegExp(r"^([0-9]+)?(\.[0-9][0-9]?)?$");
                      if (validDecimal.hasMatch(value) == false) {
                        return 'Invalid format.';
                      }

                      return null;
                    },
                  ),
                ],
                TextFormField(
                  controller: noteState,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Note"),
                    alignLabelWithHint: true,
                  ),
                ),
                TextFormField(
                  controller: timestampState,
                  readOnly: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    label: Text("Timestamp"),
                  ),
                  onTap: () async {
                    String dateTimeString = "";
                    DateTime? date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1990, 1, 1),
                      lastDate: DateTime(9999, 1, 1),
                    );

                    if (date == null) return;
                    dateTimeString = date.year.toString() + "-" + date.month.toString().padLeft(2, '0') + "-" + date.day.toString().padLeft(2, '0');
                    timestampState.value = TextEditingValue(text: dateTimeString);

                    TimeOfDay? time = await showTimePicker(
                      context: context,
                      initialTime: const TimeOfDay(hour: 0, minute: 0),
                    );
                    if (time == null) return;
                    dateTimeString = date.year.toString() + "-" + date.month.toString().padLeft(2, '0') + "-" + date.day.toString().padLeft(2, '0') + " " + time.hour.toString().padLeft(2, '0') + ":" + time.minute.toString().padLeft(2, '0');
                    timestampState.value = TextEditingValue(text: dateTimeString);
                  },
                ),
                Focus(
                  child: TextFormField(
                    controller: tagsState,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      label: Text("Tags"),
                    ),
                  ),
                  onFocusChange: (hasFocus) {
                    String text = tagsState.value.text;
                    tagsState.value = TextEditingValue(text: text.replaceAll(RegExp(r'[ ,]+'), ' '));
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

                        Transaction? editedObject;
                        if (transaction == null) {
                          editedObject = await getit<DataSource>().transactionsDao.create(
                            type: typeState.value,
                            account: accountState.value,
                            target: typeState.value == TransactionType.transfer ? targetState.value : null,
                            amount: amountState.value.text,
                            amountAfterExchange: amountAfterExchangeState.value.text.isNotEmpty ? amountAfterExchangeState.value.text : null,
                            note: noteState.value.text.isNotEmpty ? noteState.value.text : null,
                            timestamp: timestampState.value.text.isNotEmpty ? timestampState.value.text : null,
                            tags: tagsState.value.text.isNotEmpty ? tagsState.value.text : null,
                          );
                        } else {
                          await getit<DataSource>().transactionsDao.edit(
                            transaction,
                            type: typeState.value,
                            account: accountState.value,
                            target: typeState.value == TransactionType.transfer ? targetState.value : null,
                            amount: amountState.value.text,
                            amountAfterExchange: amountAfterExchangeState.value.text.isNotEmpty ? amountAfterExchangeState.value.text : null,
                            note: noteState.value.text.isNotEmpty ? noteState.value.text : null,
                            timestamp: timestampState.value.text.isNotEmpty ? timestampState.value.text : null,
                            tags: tagsState.value.text.isNotEmpty ? tagsState.value.text : null,
                          );
                          editedObject = await getit<DataSource>().transactionsDao.find(transaction!.id);
                        }

                        processingState.value = false;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Transaction saved.'), backgroundColor: Colors.green[700]!, duration: const Duration(seconds: 2)),
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
