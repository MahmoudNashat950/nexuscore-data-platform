# NexusCore — Database Design

- **Status:** POC schema implemented; alerts and retention policies remain planned
- **Database:** PostgreSQL + TimescaleDB
**Schema version:** Initial POC — Migrations 001–003

## 1. Overview

NexusCore uses PostgreSQL with TimescaleDB to manage smart-building metadata, device state, telemetry, data quality, and alerts.

The initial POC supports:
- One tenant and one site.
- Two buildings, six floors, and 30 rooms.
- 100 simulated devices across five categories.
- 10 telemetry events per second.
- 90-day raw telemetry retention.

## 2. Entity Relationship Diagram

![NexusCore Entity Relationship Diagram](https://github.com/user-attachments/assets/3e95072e-28ec-478a-bf7f-93efc151d64e)

## 3. Table Definitions

### 3.1 Organization hierarchy

#### tenants

| Column | Type | Constraints |
|---|---|---|
| tenant_id | UUID | PK, DEFAULT gen_random_uuid() |
| name | VARCHAR(150) | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

#### sites

| Column | Type | Constraints |
|---|---|---|
| site_id | UUID | PK, DEFAULT gen_random_uuid() |
| tenant_id | UUID | NOT NULL, FK → tenants |
| name | VARCHAR(150) | NOT NULL |
| address | TEXT | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

**Additional constraints:**
- UNIQUE (tenant_id, site_id)

#### buildings

| Column | Type | Constraints |
|---|---|---|
| building_id | UUID | PK, DEFAULT gen_random_uuid() |
| tenant_id | UUID | NOT NULL |
| site_id | UUID | NOT NULL |
| name | VARCHAR(150) | NOT NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

**Additional constraints:**
- FK (tenant_id, site_id) → sites (tenant_id, site_id)
- UNIQUE (tenant_id, site_id, building_id)

#### floors

| Column | Type | Constraints |
|---|---|---|
| floor_id | UUID | PK, DEFAULT gen_random_uuid() |
| tenant_id | UUID | NOT NULL |
| site_id | UUID | NOT NULL |
| building_id | UUID | NOT NULL |
| name | VARCHAR(100) | NOT NULL |
| floor_number | INTEGER | NOT NULL |

**Additional constraints:**
- FK (tenant_id, site_id, building_id) → buildings
- UNIQUE (tenant_id, site_id, building_id, floor_id)
- UNIQUE (building_id, floor_number)

#### rooms

| Column | Type | Constraints |
|---|---|---|
| room_id | UUID | PK, DEFAULT gen_random_uuid() |
| tenant_id | UUID | NOT NULL |
| site_id | UUID | NOT NULL |
| building_id | UUID | NOT NULL |
| floor_id | UUID | NOT NULL |
| name | VARCHAR(100) | NOT NULL |
| room_type | VARCHAR(50) | NOT NULL, CHECK |

**Additional constraints:**
- FK (tenant_id, site_id, building_id, floor_id) → floors
- UNIQUE (tenant_id, site_id, room_id)

### 3.2 Device management

#### devices

| Column | Type | Constraints |
|---|---|---|
| device_id | UUID | PK, DEFAULT gen_random_uuid() |
| device_code | VARCHAR(50) | UNIQUE, NOT NULL |
| tenant_id | UUID | NOT NULL |
| site_id | UUID | NOT NULL |
| room_id | UUID | NOT NULL |
| device_type | VARCHAR(50) | NOT NULL, CHECK |
| lifecycle_status | VARCHAR(20) | NOT NULL, DEFAULT 'active', CHECK |
| installed_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |
| firmware_version | VARCHAR(50) | NULL |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

**Additional constraints:**
- FK (tenant_id, site_id, room_id) → rooms (tenant_id, site_id, room_id)
- CHECK device_type against the five supported device types.
- CHECK lifecycle_status against active, disabled, retired.

**Indexes:**
- (tenant_id, site_id, room_id)
- (device_type, lifecycle_status)

#### device_state

| Column | Type | Constraints |
|---|---|---|
| device_id | UUID | PK, FK → devices, ON DELETE CASCADE |
| connectivity_status | VARCHAR(10) | NOT NULL, DEFAULT 'offline', CHECK |
| last_seen_at | TIMESTAMPTZ | NULL |
| last_event_timestamp | TIMESTAMPTZ | NULL |
| latest_measurements | JSONB | NULL |
| offline_since | TIMESTAMPTZ | NULL |
| recovered_at | TIMESTAMPTZ | NULL |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

### 3.3 Telemetry and data quality

#### telemetry

A unified TimescaleDB hypertable for all five device categories.

| Column | Type | Constraints |
|---|---|---|
| event_id | UUID | NOT NULL |
| device_id | UUID | NOT NULL |
| timestamp | TIMESTAMPTZ | NOT NULL; partitioning column |
| ingested_at | TIMESTAMPTZ | NOT NULL |
| sequence_number | BIGINT | NOT NULL |
| device_type | VARCHAR(50) | NOT NULL, CHECK |
| measurements | JSONB | NOT NULL |

The `measurements` JSONB object contains category-specific readings.

Example:

```json
{
  "temperature": 25.5,
  "humidity": 45,
  "air_quality": 82
}
```

Measurement validation must happen before insertion.

Important TimescaleDB constraint: unique indexes on a hypertable must include the partitioning column. Global `event_id` uniqueness is therefore enforced by the separate `event_deduplication` table.

#### event_deduplication

| Column | Type | Constraints |
|---|---|---|
| event_id | UUID | PK |
| device_id | UUID | NOT NULL, FK → devices |
| event_timestamp | TIMESTAMPTZ | NOT NULL |
| processed_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |

The event ID is inserted before telemetry persistence.

The deduplication record, telemetry insertion, and device-state update must be part of the same database transaction.

If any persistence step fails, the transaction rolls back.

A duplicate event must not create another telemetry record.

#### telemetry_quarantine

| Column | Type | Constraints |
|---|---|---|
| quarantine_id | UUID | PK, DEFAULT gen_random_uuid() |
| event_id | UUID | NULL |
| device_id | UUID | NULL |
| original_payload | JSONB | NOT NULL |
| rejection_reason | TEXT | NOT NULL |
| ingested_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |
| preserve_until | TIMESTAMPTZ | NULL |

`device_id` is nullable because an event may originate from an unknown device. The quarantine process must not require a registered-device foreign key.

Invalid events are preserved for investigation.

### 3.4 Alerts

#### alerts

| Column | Type | Constraints |
|---|---|---|
| alert_id | UUID | PK, DEFAULT gen_random_uuid() |
| tenant_id | UUID | NOT NULL |
| device_id | UUID | NULL |
| room_id | UUID | NULL |
| building_id | UUID | NULL |
| alert_type | VARCHAR(50) | NOT NULL |
| severity | VARCHAR(20) | NOT NULL, CHECK |
| message | TEXT | NOT NULL |
| status | VARCHAR(20) | NOT NULL, CHECK |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() |
| acknowledged_at | TIMESTAMPTZ | NULL |
| resolved_at | TIMESTAMPTZ | NULL |

Exactly one of `device_id`, `room_id`, or `building_id` must be populated.

Allowed severity values:
- low
- medium
- high
- critical

Allowed status values:
- active
- acknowledged
- resolved

The referenced entity must belong to the same tenant as the alert.

Multiple active alerts for the same device are permitted.

Alert lifecycle:

`active → acknowledged → resolved`

An alert may also transition directly from active to resolved.

## 4. Data Integrity Rules

1. Every device belongs to exactly one room.
2. Every device has exactly one device-state record.
3. Device lifecycle and connectivity are separate concepts.
4. Tenant/site/room relationships must remain consistent.
5. Device types and statuses are restricted to approved values.
6. Every valid telemetry event must reference a registered device.
7. Invalid events must be stored in quarantine.
8. Duplicate event IDs must not create duplicate telemetry records.
9. Exactly one alert scope must be populated.
10. Device state is updated only when an incoming event is newer.

## 5. Initial Indexing Strategy

### Implemented indexes

| Table | Index | Purpose |
|---|---|---|
| devices | (tenant_id, site_id, room_id) | Hierarchy filtering |
| devices | (device_type, lifecycle_status) | Device filtering |
| telemetry | (device_id, timestamp DESC) | Device history queries |
| telemetry | TimescaleDB timestamp index | Time-based queries |
| event_deduplication | PRIMARY KEY (event_id) | Global event deduplication |
| event_deduplication | (processed_at) | Deduplication retention management |
| telemetry_quarantine | (ingested_at DESC) | Recent quarantine records |

### Planned indexes

The following indexes will be added when the alerts table is implemented:

- alerts(tenant_id, status, created_at DESC)
- alerts(device_id, created_at DESC)
- alerts(room_id, created_at DESC)
- alerts(building_id, created_at DESC)

Avoid unnecessary indexes until actual query performance demonstrates a need.
## 6. Data Retention

| Table | Retention |
|---|---|
| telemetry | 90 days |
| event_deduplication | 90 days |
| telemetry_quarantine | 30 days by default |
| devices | Retained |
| device_state | Retained |
| alerts | Policy to be decided |

TimescaleDB retention policies will automatically remove expired telemetry chunks.

Deduplication retention must cover the expected retry and replay window. Replays after deduplication records expire may be inserted again.

Quarantine records may be preserved for investigation.

**Implementation status:**

The retention periods above are design targets and have not yet been
configured as automatic database retention policies.

The telemetry and deduplication tables currently have no automatic
retention jobs. Quarantine records are also retained until a cleanup
policy is implemented.

Retention policies will be configured and tested in a later phase.

## 7. Ingestion Transaction

The ingestion service follows this sequence:

1. Receive MQTT message.
2. Parse JSON.
3. Validate event structure.
4. Validate registered device and tenant/site ownership.
5. Validate measurements for the device type.
6. Insert `event_id` into `event_deduplication`.
7. Insert valid event into `telemetry`.
8. Update `device_state` only if the event is newer.
9. Commit the transaction.
10. Send application-level acknowledgment.

Invalid events are stored in quarantine.

Duplicate events are not inserted again.

If database persistence fails, do not send the application-level acknowledgment. The event must remain available for retry.

## 8. Implementation Notes

- PostgreSQL generates internal entity UUIDs.
- The simulator generates telemetry event UUIDs.
- Event timestamps use UTC.
- Backend assigns `ingested_at`.
- Telemetry is stored in one unified hypertable.
- Device status is derived from successfully processed telemetry.
- MQTT QoS 1 is used with application-level acknowledgment.
- SQL implementation must validate all constraints and relationships.
- Retention policies must be tested with late-arriving events and replay behavior.


## 9. Implementation Status

### Implemented

| Component | Migration | Status |
|---|---|---|
| Organization hierarchy | 001 | Implemented |
| Device management | 002 | Implemented |
| Automatic device-state creation | 002 | Implemented |
| Telemetry hypertable | 003 | Implemented |
| Event deduplication table | 003 | Implemented |
| Telemetry quarantine table | 003 | Implemented |
| Python telemetry schemas | — | Implemented |
| Database connection pool | — | Implemented |
| Telemetry persistence repository | — | Implemented |
| Schema validation tests | — | 7 tests passing |

### Planned / Not Yet Implemented

- Alerts database table.
- MQTT subscriber and message acknowledgment.
- Database-backed device and tenant/site validation.
- Quarantine processing.
- Device offline-status monitoring.
- Automatic data-retention policies.
- Integration and end-to-end tests.


##10. Future Extensions

Possible future additions:
- Continuous aggregates for long-term analytics.
- Kafka for scalable event streaming and replay.
- Spark for historical processing and feature engineering.
- ML anomaly detection and predictive maintenance.
- Prometheus and Grafana for advanced observability.
- Azure deployment and centralized model management.
