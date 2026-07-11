#!/usr/bin/env python3
"""Focused overlap, identity, and metric invariants for the canonical registry."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


FIXED_TIME = "2026-07-11T00:00:00Z"
EXPECTED_STABLE_METRICS = {
    "canonicalCollectionWrappers": 7,
    "canonicalEntities": 1113,
    "collectionAndResearchRows": 207,
    "curatedGameBoyMemberships": 201,
    "distinctCanonicalTitles": 1106,
    "localLaunchCandidateTitles": 790,
    "localPayloadRecords": 883,
    "locallyInstalledNativeTitles": 0,
    "localPayloadTitles": 879,
    "manualReviewRelationships": 6,
    "nativePackageManifests": 124,
    "checksRecordedTitles": 12,
    "meaningfulActionEvidenceTitles": 2,
    "researchRows": 200,
    "resolvedDuplicateTitleRecords": 11,
    "topLevelLauncherCards": 153,
    "totalSourceRecords": 1449,
    "unresolvedPossibleDuplicates": 5,
}
EXPECTED_SOURCE_COUNTS = {
    "catalog": 153,
    "game-boy-vault": 743,
    "game-boy-curated": 201,
    "board-games": 200,
    "classic-pc": 28,
    "native-package-shelves": 124,
}
CONFIRMED_SAME_ENTITY = [
    ("record:board-games:go", "record:catalog:kigo-lan"),
    ("record:board-games:backgammon", "record:catalog:gnubg-lan"),
    ("record:board-games:reversi-othello-style", "record:catalog:kreversi-lan"),
    ("record:board-games:connect-four-style", "record:catalog:kfourinline-lan"),
    ("record:board-games:battleship-style", "record:catalog:knavalbattle-lan"),
    ("record:board-games:nine-men-s-morris", "record:catalog:morris-lan"),
    ("record:board-games:gomoku-five-in-a-row", "record:catalog:bovo-lan"),
    ("record:game-boy-vault:pocket-bomberman", "record:game-boy-vault:pocket-bomberman-952660d1"),
    ("record:game-boy-vault:space-invaders", "record:game-boy-vault:space-invaders-48f70d85"),
    ("record:game-boy-vault:wario-land-ii", "record:game-boy-vault:wario-land-ii-40f366cc"),
    ("record:catalog:lemmings", "record:classic-pc:lemmings-ma"),
]


def parse_args() -> argparse.Namespace:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=root)
    return parser.parse_args()


def check(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    check(isinstance(value, dict), f"Registry is not an object: {path}")
    return value


def generate(root: Path, output: Path) -> None:
    subprocess.run(
        [
            sys.executable,
            str(root / "scripts/build_canonical_game_registry.py"),
            "--generated-at",
            FIXED_TIME,
            "--skip-installed-package-query",
            "--output",
            str(output),
        ],
        cwd=root,
        check=True,
        text=True,
    )


def main() -> int:
    args = parse_args()
    root = args.repo_root.resolve()
    output_a = root / "qa/canonical-registry-test-output-a.json"
    output_b = root / "qa/canonical-registry-test-output-b.json"
    try:
        generate(root, output_a)
        generate(root, output_b)
        check(output_a.read_bytes() == output_b.read_bytes(), "Fixed-input registry builds are not byte-reproducible")
        registry = load(output_a)
    finally:
        output_a.unlink(missing_ok=True)
        output_b.unlink(missing_ok=True)

    metrics = registry["metrics"]
    check(metrics == EXPECTED_STABLE_METRICS, f"Metric drift: {json.dumps(metrics, sort_keys=True)}")
    encoded = json.dumps(registry, sort_keys=True)
    for legacy_key in ('"playableNow"', '"qaVerified"', '"readyNow"'):
        check(legacy_key not in encoded, f"Legacy readiness key leaked: {legacy_key}")
    sources = {row["sourceCollection"]: row["recordCount"] for row in registry["sources"]}
    check(sources == EXPECTED_SOURCE_COUNTS, f"Source-count drift: {sources}")

    records = {record["recordId"]: record for record in registry["records"]}
    entities = {entity["entityId"]: entity for entity in registry["entities"]}
    check(
        not entities["game:classic:lemmings"]["dimensions"]["meaningfulActionEvidence"],
        "Lemmings canvas-start check must not count as meaningful-action evidence",
    )
    check(
        entities["game:catalog:pillage-first-lan"]["dimensions"]["meaningfulActionEvidence"],
        "Pillage First create-world action evidence missing",
    )
    check(len(records) == metrics["totalSourceRecords"], "totalSourceRecords does not match records")
    check(len(entities) == metrics["canonicalEntities"], "canonicalEntities does not match entities")
    check(
        sum(entity["kind"] == "title" for entity in entities.values()) == metrics["distinctCanonicalTitles"],
        "distinctCanonicalTitles does not match title entities",
    )

    for record_a, record_b in CONFIRMED_SAME_ENTITY:
        check(records[record_a]["entityId"] == records[record_b]["entityId"], f"Confirmed group split: {record_a}")

    memberships = [record for record in records.values() if record["recordType"] == "collection-membership"]
    check(len(memberships) == 201, "Curated Game Boy membership count changed")
    for membership in memberships:
        vault_record = records[membership["evidence"]["sameAsRecordId"]]
        check(membership["entityId"] == vault_record["entityId"], f"Curated row became a second title: {membership['recordId']}")
        check(membership["evidence"]["dedupeEvidence"] == "source-id-and-sha256-match", "Curated dedupe evidence weakened")

    wrappers = registry["collectionWrappers"]
    check(len(wrappers) == 7, "Collection wrapper count changed")
    for wrapper in wrappers:
        entity = entities[wrapper["entityId"]]
        check(entity["kind"] == "collection", f"Wrapper counted as a title: {wrapper['catalogId']}")

    for relationship in registry["relationships"]:
        if relationship["keptSeparate"]:
            check(relationship["entityA"] != relationship["entityB"], f"Review relationship was merged: {relationship['relationshipId']}")
    possible_duplicates = [row for row in registry["relationships"] if row["type"] == "possible-duplicate"]
    check(len(possible_duplicates) == 5, "Possible-duplicate review count changed")
    analog = next(row for row in registry["relationships"] if row["relationshipId"] == "review:catan-vs-pioneers")
    check(analog["type"] == "analog-implementation" and analog["keptSeparate"], "Catan/Pioneers relationship changed")

    title_rows = [
        record
        for record in records.values()
        if record["entityKind"] == "title" and record["recordType"] in {"launcher-card", "title-record", "research-row"}
    ]
    check(
        len(title_rows) - metrics["resolvedDuplicateTitleRecords"] == metrics["distinctCanonicalTitles"],
        "Canonical title reduction is inconsistent",
    )
    naive_sum = 153 + 743 + 201 + 200 + 28
    check(metrics["distinctCanonicalTitles"] < naive_sum, "Curated overlap was naively summed")
    check(all(target["target"].startswith("/mirrors/") for entity in entities.values() for target in entity["launcherTargets"]), "Non-local launcher target found")

    encoded = json.dumps(registry, sort_keys=True)
    check("http://" not in encoded and "https://" not in encoded, "Public registry exposes an external URL")
    check("/home/" not in encoded and "/var/www/" not in encoded, "Public registry exposes an operator path")

    print("Canonical registry invariants: PASS")
    print(json.dumps(metrics, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
