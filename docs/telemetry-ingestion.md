# Telemetry Ingestion

## 1. Overview

The NexusCore telemetry ingestion package is responsible for validating incoming telemetry events and persisting valid events into the database.

The current implementation provides:

- Telemetry event validation using Pydantic.
- PostgreSQL connection pooling using Psycopg.
- Duplicate event detection.
- Transactional telemetry persistence.
- Latest device-state updates.

**Implementation status:** Core validation and database repository implemented. MQTT message consumption and quarantine processing remain planned.

## 2. Package Structure

```text
ingestion/
├── pyproject.toml
├── requirements.txt
├── src/
│   └── nexuscore_ingestion/
│       ├── schemas.py
│       ├── config.py
│       ├── database.py
│       └── repositories/
│           └── telemetry.py
└── tests/
    └── test_schemas.py


## 3. Dependencies

The package uses:

| Dependency | Purpose |
|---|---|
| Pydantic | Telemetry event validation |
| Psycopg | PostgreSQL database access |
| Psycopg Pool | Database connection pooling |
| python-dotenv | Environment variable loading |
| Paho MQTT | MQTT client dependency; subscriber not implemented yet |
| pytest | Automated tests |

## 5. Database Configuration and Connection Pool

Database settings are loaded in `config.py` using `python-dotenv`.

The connection string is read from the `DATABASE_URL` environment variable. A development fallback is currently provided in the settings class.

The `database.py` module creates a Psycopg connection pool with:

- Minimum connections: 2
- Maximum connections: 10
- Initial state: Closed

Available functions:

| Function | Responsibility |
|---|---|
| `open_pool()` | Opens the connection pool |
| `close_pool()` | Closes the connection pool |
| `check_database()` | Checks database connectivity using `SELECT 1` |

The development fallback credentials must not be used in production. Production deployments should provide database credentials through secure environment configuration.

## 6. Telemetry Persistence

The `save_telemetry()` function in `repositories/telemetry.py` persists a validated event.

All database operations are executed within a single transaction.

### Processing Flow

1. Insert the event ID into `event_deduplication`.
2. If the event ID already exists, skip processing and return `False`.
3. Insert the event into the `telemetry` hypertable.
4. Update the corresponding device's latest state if the event timestamp is newer.
5. Commit the transaction and return `True`.

### Transactional Behavior

The deduplication record, telemetry record, and device-state update are part of the same database transaction.

If a database operation raises an exception, the transaction is rolled back. This prevents partially persisted events.

### Device-State Update

For a newly processed event with a newer timestamp, the repository:

- Sets connectivity status to `online`.
- Updates `last_seen_at`.
- Updates `last_event_timestamp`.
- Stores the latest measurements.
- Updates recovery information when the previous status was `offline`.
- Clears `offline_since`.

Older events can be stored in telemetry but do not overwrite the latest device state.
Install the package and development dependencies:


## 7. Automated Tests

Schema tests are located in:

```text
ingestion/tests/test_schemas.py
```bash
cd ingestion
pip install -e ".[dev]"