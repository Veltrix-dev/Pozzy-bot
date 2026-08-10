import 'dart:io';
import 'package:pozzy_bot/config/config.dart';
import 'package:pozzy_bot/database/models/user_roles.dart';
import 'package:sqlite3/sqlite3.dart';

abstract final class AppDatabase {
  static Database? _db;

  static Database get instance {
    final db = _db;
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return db;
  }

  static Future<void> init({String? pathOverride}) async {
    if (_db != null) return;

    final path = pathOverride ?? Config.dbPath;
    final file = File(path);
    await file.parent.create(recursive: true);

    _db = sqlite3.open(path);
    _migrate(_db!);
  }

  static void _migrate(Database db) {
    db.execute('''
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      telegram_id INTEGER NOT NULL UNIQUE,
      username TEXT,
      role TEXT NOT NULL DEFAULT '${UserRoles.user}',
      referral_code TEXT NOT NULL UNIQUE,
      referred_by_telegram_id INTEGER,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS referrals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      referrer_telegram_id INTEGER NOT NULL,
      referral_telegram_id INTEGER NOT NULL UNIQUE,
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS referral_purchase_commissions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      referrer_telegram_id INTEGER NOT NULL,
      referral_telegram_id INTEGER NOT NULL,
      purchase_id TEXT NOT NULL UNIQUE,
      purchase_amount REAL NOT NULL,
      commission_amount REAL NOT NULL,
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS user_statistics (
      telegram_id INTEGER PRIMARY KEY,
      purchases_count INTEGER NOT NULL DEFAULT 0,
      purchases_total REAL NOT NULL DEFAULT 0,
      referral_commission_total REAL NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS user_purchase_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      telegram_id INTEGER NOT NULL,
      purchase_id TEXT NOT NULL UNIQUE,
      purchase_type TEXT NOT NULL CHECK (
        purchase_type IN ('stars', 'premium', 'ton')
      ),
      quantity REAL NOT NULL CHECK (quantity > 0),
      spent_usd REAL NOT NULL CHECK (spent_usd >= 0),
      purchased_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_purchase_history_user_type_date
    ON user_purchase_history (telegram_id, purchase_type, purchased_at DESC);
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS user_balances (
      telegram_id INTEGER PRIMARY KEY,
      balance     REAL    NOT NULL DEFAULT 0,
      updated_at  TEXT    NOT NULL
    );
  ''');
  }
}
