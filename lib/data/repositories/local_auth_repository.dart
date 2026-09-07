import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import '../local/database.dart';

class LocalAuthSession {
  final int userId;
  final String username;
  final String token;

  const LocalAuthSession(this.userId, this.username, this.token);
}

class LocalAuthRepository {
  static const _iterations = 210000;
  static const _sessionLifetime = Duration(hours: 12);
  final AppDatabase db;

  LocalAuthRepository(this.db);

  Future<void> ensureDefaultUser() async {
    await db.transaction(() async {
      final countExpression = db.usersTable.id.count();
      final countQuery = db.selectOnly(db.usersTable)
        ..addColumns([countExpression]);
      final count = (await countQuery.getSingle()).read(countExpression) ?? 0;
      if (count > 0) return;
      final material = await _hashPassword('1234');
      final now = DateTime.now();
      await db.into(db.usersTable).insert(UsersTableCompanion.insert(
            username: 'admin',
            passwordHash: material.hash,
            passwordSalt: material.salt,
            passwordIterations: material.iterations,
            createdAt: now,
            updatedAt: now,
          ));
    });
  }

  Future<LocalAuthSession?> authenticate(
      String username, String password) async {
    final normalized = username.trim();
    final user = await (db.select(db.usersTable)
          ..where((t) => t.username.equals(normalized)))
        .getSingleOrNull();
    if (user == null || !await _verifyPassword(password, user)) return null;

    final token = _randomToken();
    final tokenHash = await _sha256(token);
    final now = DateTime.now();
    await db.into(db.sessionsTable).insert(SessionsTableCompanion.insert(
          tokenHash: tokenHash,
          userId: user.id,
          createdAt: now,
          expiresAt: now.add(_sessionLifetime),
        ));
    return LocalAuthSession(user.id, user.username, token);
  }

  Future<LocalAuthSession?> resumeSession(String token) async {
    final tokenHash = await _sha256(token);
    final row = await (db.select(db.sessionsTable).join([
      innerJoin(
          db.usersTable, db.usersTable.id.equalsExp(db.sessionsTable.userId)),
    ])
          ..where(db.sessionsTable.tokenHash.equals(tokenHash) &
              db.sessionsTable.revokedAt.isNull() &
              db.sessionsTable.expiresAt.isBiggerThanValue(DateTime.now())))
        .getSingleOrNull();
    if (row == null) return null;
    final user = row.readTable(db.usersTable);
    return LocalAuthSession(user.id, user.username, token);
  }

  Future<void> revokeSession(String token) async {
    final tokenHash = await _sha256(token);
    await (db.update(db.sessionsTable)
          ..where((t) => t.tokenHash.equals(tokenHash)))
        .write(SessionsTableCompanion(revokedAt: Value(DateTime.now())));
  }

  Future<void> changeCredentials({
    required int userId,
    required String username,
    required String currentPassword,
    String? newPassword,
  }) async {
    final trimmed = username.trim();
    if (trimmed.isEmpty) throw const AuthException('نام کاربری الزامی است');
    final user = await (db.select(db.usersTable)
          ..where((t) => t.id.equals(userId)))
        .getSingleOrNull();
    if (user == null || !await _verifyPassword(currentPassword, user)) {
      throw const AuthException('رمز عبور فعلی اشتباه است');
    }
    final duplicate = await (db.select(db.usersTable)
          ..where(
              (t) => t.username.equals(trimmed) & t.id.equals(userId).not()))
        .getSingleOrNull();
    if (duplicate != null) throw const AuthException('نام کاربری تکراری است');

    var hash = user.passwordHash;
    var salt = user.passwordSalt;
    var iterations = user.passwordIterations;
    if (newPassword != null && newPassword.isNotEmpty) {
      final material = await _hashPassword(newPassword);
      hash = material.hash;
      salt = material.salt;
      iterations = material.iterations;
    }
    await (db.update(db.usersTable)..where((t) => t.id.equals(userId))).write(
      UsersTableCompanion(
        username: Value(trimmed),
        passwordHash: Value(hash),
        passwordSalt: Value(salt),
        passwordIterations: Value(iterations),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<_PasswordMaterial> _hashPassword(String password) async {
    final saltBytes =
        List<int>.generate(32, (_) => Random.secure().nextInt(256));
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _iterations,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: saltBytes,
    );
    return _PasswordMaterial(
      base64Encode(await key.extractBytes()),
      base64Encode(saltBytes),
      _iterations,
    );
  }

  Future<bool> _verifyPassword(String password, UsersTableData user) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: user.passwordIterations,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(user.passwordSalt),
    );
    final actual = await key.extractBytes();
    final expected = base64Decode(user.passwordHash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  String _randomToken() => base64UrlEncode(
      List<int>.generate(48, (_) => Random.secure().nextInt(256)));

  Future<String> _sha256(String value) async =>
      base64Encode((await Sha256().hash(utf8.encode(value))).bytes);
}

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class _PasswordMaterial {
  final String hash;
  final String salt;
  final int iterations;
  const _PasswordMaterial(this.hash, this.salt, this.iterations);
}
