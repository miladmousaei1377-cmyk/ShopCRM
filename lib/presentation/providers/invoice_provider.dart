import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/invoice.dart';
import 'cart_provider.dart';

final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchInvoices();
});

final recentInvoicesProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.watch(invoiceRepositoryProvider).watchRecentInvoices();
});

final invoiceByIdProvider = FutureProvider.family<Invoice?, int>((ref, id) {
  return ref.watch(invoiceRepositoryProvider).findById(id);
});

final todaySalesTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(invoiceRepositoryProvider).getTodaySalesTotal();
});
