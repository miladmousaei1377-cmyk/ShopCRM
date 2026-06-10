import 'package:drift/drift.dart';
import '../../data/local/database.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/product.dart';

class CustomerRepository {
  final AppDatabase _db;

  CustomerRepository(this._db);

  Stream<List<Customer>> watchCustomers({String? search}) {
    final stream = search != null && search.isNotEmpty
        ? _db.customersDao.watchCustomersBySearch(search)
        : _db.customersDao.watchAllCustomers();
    return stream.map((rows) => rows.map(_mapToModel).toList());
  }

  Future<List<Customer>> getCustomers() async {
    final rows = await _db.customersDao.getAllCustomers();
    return rows.map(_mapToModel).toList();
  }

  Future<Customer?> findById(int id) async {
    final row = await _db.customersDao.findById(id);
    return row != null ? _mapToModel(row) : null;
  }

  Future<List<Customer>> getDebtors() async {
    final rows = await _db.customersDao.getDebtors();
    return rows.map(_mapToModel).toList();
  }

  Future<double> getTotalDebt() => _db.customersDao.getTotalDebt();

  Future<int> saveCustomer(Customer customer) async {
    final companion = CustomersTableCompanion(
      id: customer.id == 0 ? const Value.absent() : Value(customer.id),
      serverId: Value(customer.serverId),
      name: Value(customer.name),
      phone: Value(customer.phone),
      address: Value(customer.address),
      creditLimit: Value(customer.creditLimit),
      totalDebt: Value(customer.totalDebt),
      updatedAt: Value(customer.updatedAt),
      syncStatus: Value(customer.syncStatus.name),
    );

    if (customer.id == 0) {
      return await _db.customersDao.insertCustomer(companion);
    } else {
      await _db.customersDao.updateCustomer(companion);
      return customer.id;
    }
  }

  Future<void> updateDebt(int id, double newDebt) =>
      _db.customersDao.updateDebt(id, newDebt);

  Customer _mapToModel(CustomersTableData row) => Customer(
    id: row.id,
    serverId: row.serverId,
    name: row.name,
    phone: row.phone,
    address: row.address,
    creditLimit: row.creditLimit,
    totalDebt: row.totalDebt,
    updatedAt: row.updatedAt,
    syncStatus: SyncStatus.values.firstWhere(
      (s) => s.name == row.syncStatus,
      orElse: () => SyncStatus.pending,
    ),
  );
}
