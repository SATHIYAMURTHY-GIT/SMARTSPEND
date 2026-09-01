import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import '../../models/notification_preferences.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/ocr_provider.dart';
import '../../providers/receipt_upload_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/receipt_upload_service.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({this.expense, super.key});

  static const List<String> supportedPaymentMethods = [
    'Cash',
    'Debit card',
    'Credit card',
    'UPI',
    'Bank transfer',
    'Other',
  ];

  final Expense? expense;

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _merchantController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customCategoryKey = '__custom_category__';
  bool _showCustomCategory = false;
  ExpenseType _type = ExpenseType.debit;
  String? _paymentMethod;
  DateTime _date = _dayOnly(DateTime.now());
  XFile? _selectedReceiptFile;
  bool _removeExistingReceipt = false;
  bool _isSaving = false;
  bool _isUploadingReceipt = false;
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      _loadExpense(widget.expense);
    }
  }

  @override
  void didUpdateWidget(covariant AddExpenseScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expense != widget.expense) {
      _loadExpense(widget.expense);
    }
  }

  void _resetForm() {
    _amountController.clear();
    _categoryController.clear();
    _customCategoryController.clear();
    _merchantController.clear();
    _descriptionController.clear();
    _showCustomCategory = false;
    _type = ExpenseType.debit;
    _paymentMethod = null;
    _date = _dayOnly(DateTime.now());
    _selectedReceiptFile = null;
    _removeExistingReceipt = false;
    _isSaving = false;
    _isUploadingReceipt = false;
    _isProcessingOcr = false;
    if (mounted) {
      setState(() {});
    }
  }

  void _loadExpense(Expense? expense) {
    if (expense == null) {
      _resetForm();
      return;
    }
    _amountController.text = _formatMinorUnits(expense.amount);
    _categoryController.text = expense.category ?? '';
    _customCategoryController.clear();
    _showCustomCategory = false;
    _merchantController.text = expense.merchant ?? '';
    _descriptionController.text = expense.description ?? '';
    _type = expense.type;
    _paymentMethod = expense.paymentMethod;
    _date = _dayOnly(expense.date ?? DateTime.now());
    _selectedReceiptFile = null;
    _removeExistingReceipt = false;
    _isSaving = false;
    _isUploadingReceipt = false;
    _isProcessingOcr = false;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _customCategoryController.dispose();
    _merchantController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selectedDate != null) setState(() => _date = _dayOnly(selectedDate));
  }

  Future<void> _saveExpense() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final amount = _parseMinorUnits(_amountController.text);
    if (amount == null || amount <= 0) return;

    final existingCategories = ref
        .read(expensesProvider)
        .maybeWhen(
          data: (items) => deriveAvailableCategories(
            items.map((expense) => expense.category),
          ),
          orElse: () => const <String>[],
        );
    final rawCategoryValue = _showCustomCategory
        ? _customCategoryController.text
        : _categoryController.text;
    final categoryName = resolveCategorySelection(
      rawCategoryValue,
      existingCategories,
    );

    setState(() => _isSaving = true);
    String? uploadedReceiptUrl;

    try {
      if (_selectedReceiptFile != null) {
        setState(() => _isUploadingReceipt = true);
        final service = ref.read(receiptUploadServiceProvider);
        uploadedReceiptUrl = await service.uploadReceiptFile(
          _selectedReceiptFile!,
        );
      }

      final resolvedReceiptUrl = _selectedReceiptFile != null
          ? uploadedReceiptUrl
          : _removeExistingReceipt
          ? null
          : widget.expense?.receiptUrl;

      final draft = Expense(
        id: widget.expense?.id ?? '',
        userId: '',
        amount: amount,
        type: _type,
        category: categoryName.isEmpty
            ? normalizeCategoryName(_categoryController.text)
            : categoryName,
        merchant: _optionalValue(_merchantController.text),
        description: _optionalValue(_descriptionController.text),
        date: _date,
        paymentMethod: _paymentMethod,
        receiptUrl: resolvedReceiptUrl,
        createdAt: widget.expense?.createdAt,
        updatedAt: widget.expense?.updatedAt,
      );

      final repository = ref.read(expenseRepositoryProvider);
      if (widget.expense == null) {
        await repository.createExpense(draft);
      } else {
        await repository.updateExpense(draft);
      }
      _triggerExpenseAlerts(draft);
      _resetForm();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.expense == null
                ? 'Expense saved successfully.'
                : 'Expense updated successfully.',
          ),
        ),
      );
      context.go('/expenses');
    } on ReceiptUploadException catch (error) {
      _showError(error.message);
    } on FirebaseException {
      _showError('We could not save this expense. Please try again.');
    } on StateError {
      _showError('Please sign in before saving an expense.');
    } catch (_) {
      _showError('We could not save this expense. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingReceipt = false;
        });
      }
    }
  }

  void _triggerExpenseAlerts(Expense draft) {
    if (draft.type != ExpenseType.debit) return;

    try {
      final notifPrefs =
          ref.read(notificationPreferencesProvider).value ??
              const NotificationPreferences();
      final notifService = ref.read(notificationServiceProvider);

      // 1. Large expense alert
      if (notifPrefs.largeExpenseAlertsEnabled &&
          draft.amount >= notifPrefs.largeExpenseThresholdMinorUnits) {
        final target = draft.merchant ?? draft.category ?? 'an expense';
        notifService.showLargeExpenseAlert(
          title: 'Large Expense Alert',
          body:
              'A large expense of ${formatMinorUnits(draft.amount)} was recorded for $target.',
        );
      }

      // 2. Budget alert
      if (notifPrefs.budgetAlertsEnabled) {
        final budget = ref.read(budgetProvider).value;
        if (budget != null && budget.monthlyLimitMinorUnits > 0) {
          final allExpenses =
              ref.read(expensesProvider).value ?? const <Expense>[];
          final now = draft.date ?? DateTime.now();
          final currentMonthDebits = allExpenses
                  .where((e) =>
                      e.type == ExpenseType.debit &&
                      e.id != draft.id &&
                      e.date != null &&
                      e.date!.year == now.year &&
                      e.date!.month == now.month)
                  .fold<int>(0, (total, e) => total + e.amount) +
              draft.amount;

          if (currentMonthDebits >= budget.monthlyLimitMinorUnits) {
            notifService.showBudgetAlert(
              title: 'Budget Alert',
              body:
                  'Budget exceeded! You have spent ${formatMinorUnits(currentMonthDebits)} of your ${formatMinorUnits(budget.monthlyLimitMinorUnits)} monthly budget.',
            );
          } else if (currentMonthDebits >=
              (budget.monthlyLimitMinorUnits * 0.8).toInt()) {
            final percentage = (currentMonthDebits / budget.monthlyLimitMinorUnits * 100).round();
            notifService.showBudgetAlert(
              title: 'Budget Alert',
              body:
                  'You have used $percentage% of your monthly budget (${formatMinorUnits(currentMonthDebits)} of ${formatMinorUnits(budget.monthlyLimitMinorUnits)}).',
            );
          }
        }
      }
    } catch (_) {
      // Notification errors should never block expense operations
    }
  }

  Future<void> _showReceiptSourcePicker() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            if (_selectedReceiptFile != null ||
                widget.expense?.receiptUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove receipt'),
                onTap: () {
                  _selectedReceiptFile = null;
                  if (mounted) setState(() {});
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final service = ref.read(receiptUploadServiceProvider);
      final file = await service.pickReceiptImage(source: source);
      if (!mounted || file == null) return;

      setState(() {
        _selectedReceiptFile = file;
        _removeExistingReceipt = false;
      });
    } on ReceiptUploadException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.message ?? 'Unable to access the selected media.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _processReceiptOcr() async {
    final file = _selectedReceiptFile;
    if (file == null || _isSaving) return;

    setState(() => _isProcessingOcr = true);
    try {
      final service = ref.read(receiptOcrServiceProvider);
      final result = await service.extractFromImage(file);
      if (!mounted) return;

      if (!result.hasSuggestions) {
        _showError(
          'We could not read useful details from this receipt. You can keep entering the expense manually.',
        );
        return;
      }

      final reviewedResult = await _showOcrReviewSheet(result);
      if (reviewedResult == null) {
        _showError(
          'OCR cancelled. You can continue filling in the expense manually.',
        );
        return;
      }

      _applyOcrSuggestions(reviewedResult);
    } on OcrException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError(
        'We could not read the receipt image right now. You can continue manually.',
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessingOcr = false);
      }
    }
  }

  void _applyOcrSuggestions(OcrExtractionResult result) {
    if (result.merchant != null && result.merchant!.trim().isNotEmpty) {
      _merchantController.text = result.merchant!.trim();
      _merchantController.selection = TextSelection.fromPosition(
        TextPosition(offset: _merchantController.text.length),
      );
    }

    if (result.amountInMinorUnits != null) {
      _amountController.text = _formatMinorUnits(result.amountInMinorUnits!);
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountController.text.length),
      );
    }

    if (result.date != null) {
      _date = _dayOnly(result.date!);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<OcrExtractionResult?> _showOcrReviewSheet(
    OcrExtractionResult result,
  ) async {
    final merchantController = TextEditingController(
      text: result.merchant ?? '',
    );
    final amountController = TextEditingController(
      text: result.amountInMinorUnits == null
          ? ''
          : _formatMinorUnits(result.amountInMinorUnits!),
    );
    var selectedDate = result.date ?? _date;

    final reviewed = await showModalBottomSheet<OcrExtractionResult?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Review OCR suggestions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'OCR may need correction. Please review and edit the values before saving.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: merchantController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant',
                            prefixIcon: Icon(Icons.storefront_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Amount (₹)',
                            prefixIcon: Icon(Icons.currency_rupee),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate == null) return;
                            setSheetState(
                              () => selectedDate = _dayOnly(pickedDate),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerLow,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Date',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat.yMMMd().format(selectedDate),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (result.items.isNotEmpty) ...[
                          Text(
                            'Detected items',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ...result.items.map(
                            (item) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                  if (item.quantity != null ||
                                      item.price != null) ...[
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 4,
                                      children: [
                                        if (item.quantity != null)
                                          Text(
                                            'Qty: ${item.quantity}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        if (item.price != null)
                                          Text(
                                            'Price: ₹${item.price}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              child: const Text('Cancel OCR'),
                            ),
                            FilledButton(
                              onPressed: () {
                                final cleanedMerchant = merchantController.text
                                    .trim();
                                final cleanedAmount = amountController.text
                                    .trim();
                                final parsedAmount = cleanedAmount.isEmpty
                                    ? null
                                    : _parseMinorUnits(cleanedAmount);
                                Navigator.of(context).pop(
                                  OcrExtractionResult(
                                    merchant: cleanedMerchant.isEmpty
                                        ? null
                                        : cleanedMerchant,
                                    amountInMinorUnits: parsedAmount,
                                    date: selectedDate,
                                    items: result.items,
                                    rawText: result.rawText,
                                  ),
                                );
                              },
                              child: const Text('Apply'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    return reviewed;
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isEditing = widget.expense != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final existingCategories = ref
        .watch(expensesProvider)
        .maybeWhen(
          data: (items) => deriveAvailableCategories(
            items.map((expense) => expense.category),
          ),
          orElse: () => const <String>[],
        );

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Expense' : 'Add Expense')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 28 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Update transaction' : 'Record a transaction',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Keep the details simple. You can add more context whenever you need it.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                  validator: (value) =>
                      (_parseMinorUnits(value ?? '') ?? 0) <= 0
                      ? 'Enter an amount greater than zero'
                      : null,
                ),
                const SizedBox(height: 20),
                Text('Transaction type', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                SegmentedButton<ExpenseType>(
                  segments: const [
                    ButtonSegment(
                      value: ExpenseType.debit,
                      label: Text('Debit'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                    ButtonSegment(
                      value: ExpenseType.credit,
                      label: Text('Credit'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) =>
                      setState(() => _type = selection.first),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  key: ValueKey('category_${_showCustomCategory ? _customCategoryKey : _categoryController.text}'),
                  initialValue: _showCustomCategory
                      ? _customCategoryKey
                      : (existingCategories.contains(_categoryController.text)
                            ? _categoryController.text
                            : null),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                    hintText: 'Select category',
                  ),
                  items: [
                    ...existingCategories.map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(
                          category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: '__custom_category__',
                      child: Text('Add new category...'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      setState(() {
                        _categoryController.clear();
                        _customCategoryController.clear();
                        _showCustomCategory = false;
                      });
                      return;
                    }

                    if (value == _customCategoryKey) {
                      setState(() {
                        _categoryController.clear();
                        _showCustomCategory = true;
                      });
                      return;
                    }

                    setState(() {
                      _categoryController.text = value;
                      _customCategoryController.clear();
                      _showCustomCategory = false;
                    });
                  },
                  validator: (value) {
                    final selectedValue = _showCustomCategory
                        ? _customCategoryController.text
                        : value;
                    final resolved = resolveCategorySelection(
                      selectedValue,
                      existingCategories,
                    );
                    return resolved.isEmpty ? 'Category is required' : null;
                  },
                ),
                if (_showCustomCategory) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'New category',
                      prefixIcon: Icon(Icons.drive_file_rename_outline),
                    ),
                    onChanged: (value) => setState(() {}),
                    validator: (value) {
                      final categoryValue = value ?? '';
                      final resolved = resolveCategorySelection(
                        categoryValue,
                        existingCategories,
                      );
                      return resolved.isEmpty ? 'Enter a new category' : null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant (optional)',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                _DateFieldCard(
                  date: _date,
                  isSaving: _isSaving,
                  onTap: _selectDate,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('payment_$_paymentMethod'),
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  hint: const Text('Select a method'),
                  isExpanded: true,
                  items: AddExpenseScreen.supportedPaymentMethods
                      .map(
                        (method) => DropdownMenuItem(
                          value: method,
                          child: Text(
                            method,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _paymentMethod = value),
                ),
                const SizedBox(height: 20),
                _ReceiptAttachmentCard(
                  isSaving: _isSaving,
                  isUploading: _isUploadingReceipt,
                  isProcessingOcr: _isProcessingOcr,
                  existingReceiptUrl: _removeExistingReceipt
                      ? null
                      : widget.expense?.receiptUrl,
                  selectedReceiptFile: _selectedReceiptFile,
                  onAttach: _showReceiptSourcePicker,
                  onOcr: _processReceiptOcr,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveExpense,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _isSaving
                        ? (_isUploadingReceipt
                              ? 'Uploading receipt...'
                              : 'Saving...')
                        : isEditing
                        ? 'Update expense'
                        : 'Save expense',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String? _optionalValue(String value) =>
      value.trim().isEmpty ? null : value.trim();

  static int? _parseMinorUnits(String value) {
    final normalized = value.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(normalized)) return null;
    final parts = normalized.split('.');
    final whole = int.tryParse(parts.first);
    final minor = int.tryParse(
      parts.length == 2 ? parts[1].padRight(2, '0') : '00',
    );
    if (whole == null || minor == null) return null;
    return whole * 100 + minor;
  }

  static String _formatMinorUnits(int amount) =>
      '${amount ~/ 100}.${(amount % 100).toString().padLeft(2, '0')}';
}

class _DateFieldCard extends StatelessWidget {
  const _DateFieldCard({
    required this.date,
    required this.isSaving,
    required this.onTap,
  });

  final DateTime date;
  final bool isSaving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dateText = DateFormat.yMMMd().format(date);

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Date',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateText,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReceiptAttachmentCard extends StatelessWidget {
  const _ReceiptAttachmentCard({
    required this.isSaving,
    required this.isUploading,
    required this.isProcessingOcr,
    required this.existingReceiptUrl,
    required this.selectedReceiptFile,
    required this.onAttach,
    required this.onOcr,
  });

  final bool isSaving;
  final bool isUploading;
  final bool isProcessingOcr;
  final String? existingReceiptUrl;
  final XFile? selectedReceiptFile;
  final VoidCallback onAttach;
  final VoidCallback onOcr;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        selectedReceiptFile != null || existingReceiptUrl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.receipt_long_outlined),
                const Text('Receipt'),
                TextButton.icon(
                  onPressed: isSaving ? null : onAttach,
                  icon: const Icon(Icons.attach_file),
                  label: Text(hasReceipt ? 'Replace' : 'Attach'),
                ),
              ],
            ),
            if (isUploading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Uploading receipt...'),
            ] else if (selectedReceiptFile != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: isSaving || isProcessingOcr ? null : onOcr,
                  icon: isProcessingOcr
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.document_scanner_outlined),
                  label: Text(isProcessingOcr ? 'Reading receipt...' : 'OCR'),
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(selectedReceiptFile!.path),
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ] else if (existingReceiptUrl != null &&
                existingReceiptUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  existingReceiptUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    height: 180,
                    child: Center(child: Text('Receipt unavailable')),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text('No receipt attached yet.'),
            ],
          ],
        ),
      ),
    );
  }
}
