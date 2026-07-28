# Database Schema

This document defines the SQLite database schema for the Pharmacy Dues Tracker.

## Tables

### `pharmacies`
Stores information about each pharmacy.
```sql
CREATE TABLE pharmacies (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  party_code TEXT UNIQUE,      -- from Excel, used as the matching key on re-upload, not shown in UI
  name TEXT,
  salesman TEXT,               -- salesman representative, nullable
  city TEXT,                   -- city/area of the pharmacy, nullable
  created_at TEXT
);
```

### `invoices`
Stores outstanding and paid invoice details linked to pharmacies.
```sql
CREATE TABLE invoices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pharmacy_id INTEGER REFERENCES pharmacies(id),
  invoice_number TEXT,
  invoice_date TEXT,
  amount REAL,                 -- original invoice amount
  due_amount REAL,             -- outstanding balance, drives all "total due" calculations
  due_date TEXT,               -- days-overdue/until-due always computed live from this, never stored
  status TEXT CHECK(status IN ('open', 'paid')),
  paid_date TEXT,
  created_at TEXT
);
```

### `reminders`
Stores the scheduled call reminders for pharmacies.
```sql
CREATE TABLE reminders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  pharmacy_id INTEGER REFERENCES pharmacies(id), -- nullable, set only when reminder_type = 'pharmacy'
  reminder_type TEXT CHECK(reminder_type IN ('pharmacy','salesman')),
  salesman_name TEXT,                            -- nullable, set only when reminder_type = 'salesman'
  scheduled_date TEXT,
  scheduled_time TEXT,                           -- format HH:mm, nullable
  status TEXT CHECK(status IN ('pending', 'done', 'rescheduled')),
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

- **Reminders are Append-Only**: Rescheduling a call creates a new row in the `reminders` table rather than editing the old one, to preserve the complete call history.
- **Permanent Invoices**: Paid invoices are flagged with `status = 'paid'` and are kept permanently in the database. There is no automatic deletion or purging of any data.
- **Computed Overdue/Until-Due**: Calculations such as days-overdue or days-until-due are always computed live from the `due_date` field in Dart and are never stored statically in the database.
