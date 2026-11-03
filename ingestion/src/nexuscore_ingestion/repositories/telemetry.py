import json

from nexuscore_ingestion.database import pool
from nexuscore_ingestion.schemas import TelemetryEvent



def save_telemetry(event: TelemetryEvent) -> bool:
    """
    Persist a telemetry event.

    Returns:
        True: Event successfully stored.
        False: Event was already processed.
    """

    with pool.connection() as conn:
        with conn.transaction():

            # 1. Deduplication
            cursor = conn.execute(
                """
                INSERT INTO event_deduplication (
                    event_id,
                    device_id,
                    event_timestamp
                )
                VALUES (%s, %s, %s)
                ON CONFLICT (event_id) DO NOTHING
                RETURNING event_id
                """,
                (
                    event.event_id,
                    event.device_id,
                    event.timestamp,
                ),
            )

            if cursor.fetchone() is None:
                return False

            # 2. Store telemetry
            conn.execute(
                """
                INSERT INTO telemetry (
                    event_id,
                    device_id,
                    timestamp,
                    sequence_number,
                    device_type,
                    measurements
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                """,
                (
                    event.event_id,
                    event.device_id,
                    event.timestamp,
                    event.sequence_number,
                    event.device_type,
                    json.dumps(event.measurements),
                ),
            )

            # 3. Update latest device state
            conn.execute(
                """
                UPDATE device_state
                SET
                    connectivity_status = 'online',
                    last_seen_at = NOW(),
                    last_event_timestamp = %s,
                    latest_measurements = %s,
                    recovered_at = CASE
                        WHEN connectivity_status = 'offline' THEN NOW()
                        ELSE recovered_at
                    END,
                    offline_since = NULL,
                    updated_at = NOW()
                WHERE device_id = %s
                  AND (
                      last_event_timestamp IS NULL
                      OR last_event_timestamp < %s
                  )
                """,
                (
                    event.timestamp,
                    json.dumps(event.measurements),
                    event.device_id,
                    event.timestamp,
                ),
            )

            return True
