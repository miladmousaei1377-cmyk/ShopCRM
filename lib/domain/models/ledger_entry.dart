enum LedgerEntryType { debt, payment, creditPurchase, adjustment, reversal }

enum LedgerDirection { debit, credit }

extension LedgerEntryTypeLabel on LedgerEntryType {
  String get label => switch (this) {
        LedgerEntryType.debt => 'بدهی',
        LedgerEntryType.payment => 'پرداخت',
        LedgerEntryType.creditPurchase => 'خرید اعتباری',
        LedgerEntryType.adjustment => 'اصلاح حساب',
        LedgerEntryType.reversal => 'برگشت یا ابطال',
      };
}

class LedgerEntry {
  final String id;
  final int customerId;
  final String customerName;
  final String? customerPhone;
  final LedgerEntryType type;
  final int amount;
  final LedgerDirection direction;
  final DateTime operationDate;
  final String? description;
  final int? invoiceId;
  final String? invoiceNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? reversesEntryId;
  final int balanceAfter;

  const LedgerEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.type,
    required this.amount,
    required this.direction,
    required this.operationDate,
    this.description,
    this.invoiceId,
    this.invoiceNumber,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.reversesEntryId,
    this.balanceAfter = 0,
  });

  int get signedAmount => direction == LedgerDirection.debit ? amount : -amount;
}

class LedgerFilter {
  final String query;
  final int? customerId;
  final DateTime? from;
  final DateTime? to;
  final LedgerDirection? direction;
  final bool? hasInvoice;
  final bool ascending;
  final bool sortByAmount;

  const LedgerFilter({
    this.query = '',
    this.customerId,
    this.from,
    this.to,
    this.direction,
    this.hasInvoice,
    this.ascending = false,
    this.sortByAmount = false,
  });
}
