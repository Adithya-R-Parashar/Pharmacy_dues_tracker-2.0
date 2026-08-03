# Database Schema

This document defines the SQLite database schema for the Pharmacy Dues Tracker.

## Tables

### `pharmacies`
Stores information and aging bucket dues about each pharmacy.
```sql
CREATE TABLE pharmacies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  party_code TEXT UNIQUE,
  name TEXT,
  salesman TEXT,
  city TEXT,
  total_amount REAL,         -- total outstanding; overwritten on every import
  bucket_121_180 REAL,       -- nullable; overwritten on every import
  bucket_181_270 REAL,       -- nullable; overwritten on every import
  bucket_271_360 REAL,       -- nullable; overwritten on every import
  last_import_date TEXT,     -- yyyy-MM-dd; updated on every import
  notes TEXT,                -- NEVER touched by import — user-managed only, persists forever
  created_at TEXT
);
```

### `reminders`
Stores the scheduled call reminders for pharmacies.
```sql
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pharmacy_id INTEGER,
  reminder_type TEXT CHECK(reminder_type IN ('pharmacy','salesman')),
  salesman_name TEXT,
  scheduled_date TEXT,
  scheduled_time TEXT,
  status TEXT CHECK(status IN ('pending','done','rescheduled')),
  notification_id INTEGER,
  notes TEXT,
  created_at TEXT
);
```

### `city_aliases`
Stores variant spelling names mapped to their canonical city name.
```sql
CREATE TABLE city_aliases (
  raw_value TEXT PRIMARY KEY COLLATE NOCASE, -- stored trimmed, case-insensitive match key
  canonical_city TEXT,                      -- resolved standardized city name
  created_at TEXT
);
```

## Design Notes

- **Aging-Bucket Model**: Pharmacy outstanding balance and aging buckets (`bucket_121_180`, `bucket_181_270`, `bucket_271_360`) are stored directly on the `pharmacies` table and overwritten on every import along with `last_import_date`.
- **Notes are User-Managed**: The `notes` field on `pharmacies` is never touched by import operations and persists forever until edited by the user.
- **Reminders are Append-Only**: Rescheduling a call creates a new row in the `reminders` table rather than editing the old one, to preserve the complete call history.
