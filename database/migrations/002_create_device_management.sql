
-- Migration: 002_create_device_management
-- Purpose: Create devices and their connectivity state.

BEGIN;

-- 1. Devices
CREATE TABLE devices (
    device_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_code VARCHAR(50) NOT NULL UNIQUE,

    tenant_id UUID NOT NULL,
    site_id UUID NOT NULL,
    room_id UUID NOT NULL,

    device_type VARCHAR(50) NOT NULL,
    lifecycle_status VARCHAR(20) NOT NULL DEFAULT 'active',

    installed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    firmware_version VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_devices_room_hierarchy
        FOREIGN KEY (tenant_id, site_id, room_id)
        REFERENCES rooms (tenant_id, site_id, room_id),

    CONSTRAINT chk_devices_type
        CHECK (
            device_type IN (
                'environmental_sensor',
                'energy_meter',
                'occupancy_sensor',
                'smart_lighting',
                'hvac'
            )
        ),

    CONSTRAINT chk_devices_lifecycle
        CHECK (
            lifecycle_status IN ('active', 'disabled', 'retired')
        )
);

-- 2. Device state
CREATE TABLE device_state (
    device_id UUID PRIMARY KEY,
    connectivity_status VARCHAR(10) NOT NULL DEFAULT 'offline',

    last_seen_at TIMESTAMPTZ,
    last_event_timestamp TIMESTAMPTZ,
    latest_measurements JSONB,

    offline_since TIMESTAMPTZ,
    recovered_at TIMESTAMPTZ,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_device_state_device
        FOREIGN KEY (device_id)
        REFERENCES devices (device_id)
        ON DELETE CASCADE,

    CONSTRAINT chk_device_connectivity
        CHECK (connectivity_status IN ('online', 'offline'))
);

-- 3. Automatically create initial state for every new device.
CREATE FUNCTION create_initial_device_state()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO device_state (
        device_id,
        connectivity_status
    )
    VALUES (
        NEW.device_id,
        'offline'
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_create_initial_device_state
AFTER INSERT ON devices
FOR EACH ROW
EXECUTE FUNCTION create_initial_device_state();

-- 4. Indexes
CREATE INDEX idx_devices_tenant_site_room
    ON devices (tenant_id, site_id, room_id);

CREATE INDEX idx_devices_type_lifecycle
    ON devices (device_type, lifecycle_status);

COMMIT;
