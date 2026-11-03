
from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator


DEVICE_TYPES = {
    "environmental_sensor",
    "energy_meter",
    "occupancy_sensor",
    "smart_lighting",
    "hvac",
}

MEASUREMENT_FIELDS = {
    "environmental_sensor": {"temperature", "humidity", "air_quality"},
    "energy_meter": {"power", "voltage", "current", "energy"},
    "occupancy_sensor": {"occupancy", "motion_detected"},
    "smart_lighting": {"brightness", "light_status", "power"},
    "hvac": {"temperature", "mode", "fan_speed", "power"},
}

MEASUREMENT_TYPES = {
    "environmental_sensor": {
        "temperature": (int, float),
        "humidity": (int, float),
        "air_quality": (int, float),
    },
    "energy_meter": {
        "power": (int, float),
        "voltage": (int, float),
        "current": (int, float),
        "energy": (int, float),
    },
    "occupancy_sensor": {
        "occupancy": bool,
        "motion_detected": bool,
    },
    "smart_lighting": {
        "brightness": (int, float),
        "light_status": bool,
        "power": (int, float),
    },
    "hvac": {
        "temperature": (int, float),
        "mode": str,
        "fan_speed": (int, float),
        "power": (int, float),
    },
}


class TelemetryEvent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event_id: UUID
    device_id: UUID
    tenant_id: str
    site_id: str
    timestamp: datetime
    sequence_number: int = Field(ge=1)
    device_type: str
    measurements: dict[str, Any]

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("timestamp must include a timezone")

        return value

    @field_validator("device_type")
    @classmethod
    def validate_device_type(cls, value: str) -> str:
        if value not in DEVICE_TYPES:
            raise ValueError(f"Unsupported device type: {value}")

        return value

    @field_validator("measurements")
    @classmethod
    def validate_measurement_fields(cls, value: dict, info) -> dict:
        device_type = info.data.get("device_type")

        if not value:
            raise ValueError("measurements cannot be empty")

        if device_type is None:
            return value

        allowed_fields = MEASUREMENT_FIELDS[device_type]
        received_fields = set(value.keys())
        invalid_fields = received_fields - allowed_fields

        if invalid_fields:
            raise ValueError(
                f"Invalid measurements for {device_type}: {sorted(invalid_fields)}"
            )

        return value

    @field_validator("measurements")
    @classmethod
    def validate_measurement_types(cls, value: dict, info) -> dict:
        device_type = info.data.get("device_type")

        if device_type is None:
            return value

        expected_types = MEASUREMENT_TYPES[device_type]

        for field, field_value in value.items():
            expected_type = expected_types[field]

            if expected_type is bool:
                valid = isinstance(field_value, bool)
            elif expected_type == (int, float):
                valid = (
                    isinstance(field_value, (int, float))
                    and not isinstance(field_value, bool)
                )
            else:
                valid = isinstance(field_value, expected_type)

            if not valid:
                raise ValueError(
                    f"Invalid type for '{field}'. Expected {expected_type}, "
                    f"got {type(field_value).__name__}"
                )

        return value