
-- Migration: 001_create_organization_hierarchy
-- Purpose: Create the NexusCore organization hierarchy.

BEGIN;

-- 1. Tenants
CREATE TABLE tenants (
    tenant_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Sites
CREATE TABLE sites (
    site_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_sites_tenant
        FOREIGN KEY (tenant_id)
        REFERENCES tenants (tenant_id),

    CONSTRAINT uq_sites_tenant_site
        UNIQUE (tenant_id, site_id)
);

-- 3. Buildings
CREATE TABLE buildings (
    building_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    site_id UUID NOT NULL,
    name VARCHAR(150) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT fk_buildings_site
        FOREIGN KEY (tenant_id, site_id)
        REFERENCES sites (tenant_id, site_id),

    CONSTRAINT uq_buildings_hierarchy
        UNIQUE (tenant_id, site_id, building_id)
);

-- 4. Floors
CREATE TABLE floors (
    floor_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    site_id UUID NOT NULL,
    building_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    floor_number INTEGER NOT NULL,

    CONSTRAINT fk_floors_building
        FOREIGN KEY (tenant_id, site_id, building_id)
        REFERENCES buildings (tenant_id, site_id, building_id),

    CONSTRAINT uq_floors_hierarchy
        UNIQUE (tenant_id, site_id, building_id, floor_id),

    CONSTRAINT uq_floors_number
        UNIQUE (building_id, floor_number)
);

-- 5. Rooms
CREATE TABLE rooms (
    room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    site_id UUID NOT NULL,
    building_id UUID NOT NULL,
    floor_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    room_type VARCHAR(50) NOT NULL,

    CONSTRAINT fk_rooms_floor
        FOREIGN KEY (tenant_id, site_id, building_id, floor_id)
        REFERENCES floors (tenant_id, site_id, building_id, floor_id),

    CONSTRAINT uq_rooms_hierarchy
        UNIQUE (tenant_id, site_id, room_id),

    CONSTRAINT chk_rooms_type
        CHECK (
            room_type IN (
                'office',
                'meeting_room',
                'corridor',
                'equipment_room',
                'server_room'
            )
        )
);

COMMIT;
