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
      purchase_amount_micros INTEGER NOT NULL DEFAULT 0,
      commission_amount_micros INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS user_statistics (
      telegram_id INTEGER PRIMARY KEY,
      purchases_count INTEGER NOT NULL DEFAULT 0,
      purchases_total REAL NOT NULL DEFAULT 0,
      referral_commission_total REAL NOT NULL DEFAULT 0,
      purchases_total_micros INTEGER NOT NULL DEFAULT 0,
      referral_commission_total_micros INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS gift_purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_id TEXT NOT NULL UNIQUE,
      buyer_telegram_id INTEGER NOT NULL,
      gift_kind TEXT NOT NULL,
      gift_id TEXT NOT NULL,
      price_usd REAL NOT NULL CHECK (price_usd >= 0),
      recipient TEXT NOT NULL,
      recipient_telegram_id INTEGER,
      status TEXT NOT NULL,
      error_code TEXT,
      error_detail TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_gift_purchases_buyer_status
    ON gift_purchases (buyer_telegram_id, status, updated_at DESC);
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
      spent_usd_micros INTEGER NOT NULL DEFAULT 0,
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
      balance_micros INTEGER NOT NULL DEFAULT 0,
      updated_at  TEXT    NOT NULL
    );
  ''');

    _ensureUserBalanceMicrosColumn(db);
    _ensureExactMoneyColumns(db);

    db.execute('''
    CREATE TABLE IF NOT EXISTS fragment_orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id TEXT NOT NULL UNIQUE,
      idempotency_key TEXT NOT NULL UNIQUE,
      buyer_telegram_id INTEGER NOT NULL,
      purchase_type TEXT NOT NULL CHECK (
        purchase_type IN ('stars', 'premium', 'ton')
      ),
      quantity_units INTEGER NOT NULL CHECK (quantity_units > 0),
      price_usd_micros INTEGER NOT NULL CHECK (price_usd_micros > 0),
      recipient_username TEXT NOT NULL,
      status TEXT NOT NULL CHECK (
        status IN ('created', 'processing', 'completed', 'failed', 'cancelled')
      ),
      attempt_count INTEGER NOT NULL DEFAULT 0,
      external_reference TEXT,
      api_response_json TEXT,
      error_code TEXT,
      error_detail TEXT,
      balance_reserved_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_fragment_orders_buyer_status
    ON fragment_orders (buyer_telegram_id, status, updated_at DESC);
  ''');

    db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_fragment_orders_external_reference
    ON fragment_orders (external_reference)
    WHERE external_reference IS NOT NULL;
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS ton_wallet_transfers (
      operation_id TEXT PRIMARY KEY,
      idempotency_key TEXT NOT NULL UNIQUE,
      request_identity TEXT NOT NULL,
      buyer_telegram_id INTEGER NOT NULL,
      recipient_address TEXT NOT NULL,
      amount_nano INTEGER NOT NULL CHECK (amount_nano > 0),
      price_usd_micros INTEGER NOT NULL CHECK (price_usd_micros > 0),
      status TEXT NOT NULL CHECK (
        status IN ('created', 'prepared', 'pending', 'completed', 'failed')
      ),
      signed_boc TEXT,
      message_hash TEXT UNIQUE,
      tx_hash TEXT,
      error_kind TEXT,
      error_detail TEXT,
      balance_reserved_at TEXT,
      completed_at TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_ton_wallet_transfers_status_date
    ON ton_wallet_transfers (status, updated_at);
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS fragment_star_price_cache (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      usd_per_star_micros INTEGER NOT NULL CHECK (usd_per_star_micros > 0),
      fetched_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS ton_usd_price_cache (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      usd_per_ton_micros INTEGER NOT NULL CHECK (usd_per_ton_micros > 0),
      fetched_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS usd_rub_exchange_rate (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      rate_micros INTEGER NOT NULL CHECK (rate_micros > 0),
      source_updated_at TEXT NOT NULL,
      fetched_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS usd_rub_fallback_exchange_rate (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      rate_micros INTEGER NOT NULL CHECK (rate_micros > 0),
      source_updated_at TEXT NOT NULL,
      fetched_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS exchange_rate_observations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      source TEXT NOT NULL,
      rate_micros INTEGER NOT NULL CHECK (rate_micros > 0),
      source_updated_at TEXT NOT NULL,
      fetched_at TEXT NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('accepted', 'rejected')),
      rejection_reason TEXT,
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_exchange_rate_observations_source_date
    ON exchange_rate_observations (source, created_at DESC);
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS admin_balance_adjustments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      request_id TEXT NOT NULL UNIQUE,
      admin_telegram_id INTEGER NOT NULL,
      target_telegram_id INTEGER NOT NULL,
      amount_usd_micros INTEGER NOT NULL CHECK (amount_usd_micros > 0),
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_admin_balance_adjustments_target_date
    ON admin_balance_adjustments (target_telegram_id, created_at DESC);
  ''');

    db.execute('''
    CREATE TABLE IF NOT EXISTS admin_audit_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admin_telegram_id INTEGER NOT NULL,
      action TEXT NOT NULL,
      target_telegram_id INTEGER,
      details TEXT,
      created_at TEXT NOT NULL
    );
  ''');

    db.execute('''
    CREATE INDEX IF NOT EXISTS idx_admin_audit_log_admin_date
    ON admin_audit_log (admin_telegram_id, created_at DESC);
  ''');
  }

  static void _ensureUserBalanceMicrosColumn(Database db) {
    final columns = db.select('PRAGMA table_info(user_balances);');
    final hasMicros = columns.any((row) => row['name'] == 'balance_micros');
    if (!hasMicros) {
      db.execute('''
      ALTER TABLE user_balances
      ADD COLUMN balance_micros INTEGER NOT NULL DEFAULT 0;
    ''');
    }
    db.execute('''
    UPDATE user_balances
    SET balance_micros = CAST(ROUND(balance * 1000000) AS INTEGER)
    WHERE balance_micros = 0 AND balance != 0;
  ''');
  }

  static void _ensureExactMoneyColumns(Database db) {
    _ensureIntegerColumn(
      db,
      table: 'referral_purchase_commissions',
      column: 'purchase_amount_micros',
    );
    _ensureIntegerColumn(
      db,
      table: 'referral_purchase_commissions',
      column: 'commission_amount_micros',
    );
    _ensureIntegerColumn(
      db,
      table: 'user_statistics',
      column: 'purchases_total_micros',
    );
    _ensureIntegerColumn(
      db,
      table: 'user_statistics',
      column: 'referral_commission_total_micros',
    );
    _ensureIntegerColumn(
      db,
      table: 'user_purchase_history',
      column: 'spent_usd_micros',
    );

    db.execute('''
    UPDATE referral_purchase_commissions
    SET purchase_amount_micros = CAST(ROUND(purchase_amount * 1000000) AS INTEGER)
    WHERE purchase_amount_micros = 0 AND purchase_amount != 0;
  ''');
    db.execute('''
    UPDATE referral_purchase_commissions
    SET commission_amount_micros = CAST(ROUND(commission_amount * 1000000) AS INTEGER)
    WHERE commission_amount_micros = 0 AND commission_amount != 0;
  ''');
    db.execute('''
    UPDATE user_statistics
    SET purchases_total_micros = CAST(ROUND(purchases_total * 1000000) AS INTEGER)
    WHERE purchases_total_micros = 0 AND purchases_total != 0;
  ''');
    db.execute('''
    UPDATE user_statistics
    SET referral_commission_total_micros =
      CAST(ROUND(referral_commission_total * 1000000) AS INTEGER)
    WHERE referral_commission_total_micros = 0
      AND referral_commission_total != 0;
  ''');
    db.execute('''
    UPDATE user_purchase_history
    SET spent_usd_micros = CAST(ROUND(spent_usd * 1000000) AS INTEGER)
    WHERE spent_usd_micros = 0 AND spent_usd != 0;
  ''');
  }

  static void _ensureIntegerColumn(
    Database db, {
    required String table,
    required String column,
  }) {
    final columns = db.select('PRAGMA table_info($table);');
    if (columns.any((row) => row['name'] == column)) return;
    db.execute(
      'ALTER TABLE $table ADD COLUMN $column INTEGER NOT NULL DEFAULT 0;',
    );
  }

  static void close() {
    _db?.close();
    _db = null;
  }
}
