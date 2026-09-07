import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../domain/models/ledger_entry.dart';
import 'product_provider.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(databaseProvider)),
);
final ledgerFilterProvider =
    StateProvider<LedgerFilter>((ref) => const LedgerFilter());
final ledgerEntriesProvider = StreamProvider<List<LedgerEntry>>((ref) => ref
    .watch(ledgerRepositoryProvider)
    .watchEntries(ref.watch(ledgerFilterProvider)));
final customerBalanceProvider = FutureProvider.family<int, int>(
    (ref, id) => ref.watch(ledgerRepositoryProvider).balanceForCustomer(id));
