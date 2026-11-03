CREATE TABLE telemetry (
    event_id UUID NOT NULL,
    device_id UUID NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    sequence_number BIGINT NOT NULL,
    device_type TEXT NOT NULL,
    measurements JSONB NOT NULL,

    CONSTRAINT fk_telemetry_device
        FOREIGN KEY (device_id)
        REFERENCES devices(device_id),

    CONSTRAINT chk_telemetry_device_type
        CHECK (
            device_type IN (
                'environmental_sensor',
                'energy_meter',
                'occupancy_sensor',
                'smart_lighting',
                'hvac'
            )
        )
);


CREATE TABLE event_deduplication (
    event_id UUID PRIMARY KEY,
    device_id UUID NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_event_deduplication_device
        FOREIGN KEY (device_id)
        REFERENCES devices(device_id)
        ON DELETE RESTRICT
);

CREATE TABLE telemetry_quarantine (
    quarantine_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID,
    device_id UUID,
    original_payload JSONB NOT NULL,
    rejection_reason TEXT NOT NULL,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    preserve_until TIMESTAMPTZ
);

CREATE INDEX idx_telemetry_quarantine_ingested_at
    ON telemetry_quarantine (ingested_at DESC);

CREATE INDEX idx_event_deduplication_processed_at
    ON event_deduplication (processed_at);


SELECT create_hypertable(
    'telemetry',
    'timestamp',
    if_not_exists => TRUE
);

CREATE INDEX idx_telemetry_device_timestamp
    ON telemetry (device_id, timestamp DESC);