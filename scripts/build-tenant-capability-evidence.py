#!/usr/bin/env python3

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SOURCE = ROOT / "local-evidence" / "tenant-readiness.json"
CONTRACT = ROOT / "configs" / "business-premium-capabilities.json"
OUTPUT = ROOT / "docs" / "evidence" / "tenant-capability-validation.json"

if not SOURCE.is_file():
    raise SystemExit(
        "FAIL: local tenant readiness evidence is missing"
    )

source_text = SOURCE.read_text()

prohibited_patterns = (
    r"onmicrosoft\.com",
    r"TenantId",
    r"UserPrincipalName",
    r"@[A-Za-z0-9._+-]+\.[A-Za-z]{2,}",
)

for pattern in prohibited_patterns:
    if re.search(pattern, source_text, flags=re.IGNORECASE):
        raise SystemExit(
            "FAIL: potentially identifying information detected "
            "in source evidence"
        )

source = json.loads(source_text)
contract = json.loads(CONTRACT.read_text())

required_sku = contract["product"]["sku_part_number"]

sku = next(
    (
        entry
        for entry in source["subscribed_skus"]
        if entry["sku_part_number"] == required_sku
    ),
    None,
)

if sku is None:
    raise SystemExit(
        f"FAIL: required subscription SKU missing: {required_sku}"
    )

plans = {
    plan["service_plan_name"]: plan["provisioning_status"]
    for plan in sku["service_plans"]
}

capabilities = []

for requirement in contract["required_capabilities"]:
    plan_name = requirement["service_plan_name"]
    actual_status = plans.get(plan_name, "Missing")
    required_status = requirement["required_status"]

    capabilities.append(
        {
            "id": requirement["id"],
            "display_name": requirement["display_name"],
            "service_plan_name": plan_name,
            "required_status": required_status,
            "observed_status": actual_status,
            "validated": actual_status == required_status,
        }
    )

failed = [
    item
    for item in capabilities
    if not item["validated"]
]

if failed:
    for item in failed:
        print(
            "FAIL:",
            item["id"],
            "expected",
            item["required_status"],
            "observed",
            item["observed_status"],
        )

    raise SystemExit(
        "FAIL: required Business Premium capabilities are not ready"
    )

evidence = {
    "schema_version": "1.0",
    "evidence_type": "sanitized-live-capability-validation",
    "subscription": {
        "display_name": contract["product"]["display_name"],
        "sku_part_number": required_sku,
        "enabled_units": sku["prepaid_units"]["enabled"],
        "consumed_units": sku["consumed_units"],
        "validated": True,
    },
    "capabilities": capabilities,
    "billing_protection": {
        "strategy": "manual_cancel_before_expiration",
        "cancel_before_expiration_days": 1,
    },
    "sensitive_identifiers_included": False,
}

OUTPUT.parent.mkdir(parents=True, exist_ok=True)

OUTPUT.write_text(
    json.dumps(
        evidence,
        indent=2,
        ensure_ascii=False,
    ) + "\n"
)

print(
    "PASS: sanitized live capability evidence written to "
    f"{OUTPUT.relative_to(ROOT)}"
)
