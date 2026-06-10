import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/invoice.dart';
import '../../data/repositories/invoice_repository.dart';
import 'cart_provider.dart';
import 'product_provider.dart';

final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices();
});

final recentInvoicesProvider = FutureProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).getRecentInvoices();
});

final invoiceByIdProvider = FutureProvider.family<Invoice?, int>((ref, id) {
  return ref.watch(invoiceRepositoryProvider).findById(id);
});

final todaySalesTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(invoiceRepositoryProvider).getTodaySalesTotal();
});
