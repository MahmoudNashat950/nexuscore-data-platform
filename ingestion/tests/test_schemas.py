import pytest
from pydantic import ValidationError

from nexuscore_ingestion.schemas import TelemetryEvent


@pytest.fixture
def base_event():
    return {
        "event_id": "550e8400-e29b-41d4-a716-446655440000",
        "device_id": "550e8400-e29b-41d4-a716-446655440001",
        "tenant_id": "TEN-001",
        "site_id": "SITE-001",
        "timestamp": "2026-11-02T10:00:00Z",
        "sequence_number": 1,
        "device_type": "environmental_sensor",
    }


def test_valid_telemetry_event(base_event):
    event = TelemetryEvent(
        **base_event,
        measurements={"temperature": 25.5, "humidity": 45},
    )
    assert event.device_type == "environmental_sensor"


def test_reject_invalid_device_type(base_event):
    base_event["device_type"] = "unknown_device"

    with pytest.raises(ValidationError):
        TelemetryEvent(**base_event, measurements={"temperature": 25.5})


def test_reject_invalid_measurement_field(base_event):
    with pytest.raises(ValidationError):
        TelemetryEvent(**base_event, measurements={"voltage": 220})


def test_reject_empty_measurements(base_event):
    with pytest.raises(ValidationError):
        TelemetryEvent(**base_event, measurements={})


def test_reject_invalid_measurement_type(base_event):
    with pytest.raises(ValidationError):
        TelemetryEvent(**base_event, measurements={"temperature": "hot"})


def test_reject_boolean_as_numeric_measurement(base_event):
    with pytest.raises(ValidationError):
        TelemetryEvent(**base_event, measurements={"temperature": True})


def test_accept_boolean_measurement(base_event):
    base_event["device_type"] = "occupancy_sensor"

    event = TelemetryEvent(
        **base_event,
        measurements={"occupancy": True, "motion_detected": False},
    )

    assert event.measurements["occupancy"] is True