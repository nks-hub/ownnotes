"""Write build-time telemetry values without printing endpoints or keys."""

import json
import os
from pathlib import Path
from urllib.parse import urlparse


def configuration(environment):
    values = {key: environment.get(key, "").strip() for key in (
        "SENTRY_DSN", "RYBBIT_HOST", "RYBBIT_SITE_ID",
    )}
    for key in ("SENTRY_DSN", "RYBBIT_HOST"):
        address = urlparse(values[key])
        if address.scheme != "https" or not address.hostname:
            raise ValueError(f"{key} must contain an HTTPS URL")
    dsn = urlparse(values["SENTRY_DSN"])
    if not dsn.username or not dsn.path.strip("/"):
        raise ValueError("SENTRY_DSN must contain a public key and project id")
    if not values["RYBBIT_SITE_ID"]:
        raise ValueError("RYBBIT_SITE_ID is required for official builds")
    return values | {
        "TELEMETRY_ENVIRONMENT": "production",
        "TELEMETRY_RELEASE_GATE": "false",
    }


if __name__ == "__main__":
    target = Path(__file__).resolve().parent.parent / "apps/mobile/telemetry.env"
    target.write_text(json.dumps(configuration(os.environ)), encoding="utf-8")
    target.chmod(0o600)
    print("Both telemetry integrations configured; release probe disabled.")
