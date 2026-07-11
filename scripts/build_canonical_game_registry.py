#!/usr/bin/env python3
"""Build the public canonical LAN Arcade inventory from structured manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import quote, unquote, urlparse


SCHEMA_VERSION = 1
QA_VERIFIED_LAUNCHER_STATES = {"gameplay-smoked", "service-smoke-passed"}
PLAYABLE_CLASSIC_PC_STATES = {"smoke-pass", "source-ready", "partial"}
TITLE_RECORD_TYPES = {"launcher-card", "title-record", "research-row"}


class RegistryError(RuntimeError):
    """Raised when an input cannot be reconciled without guessing."""


def parse_args() -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[1]
    mirrors_root = Path(os.environ.get("MIRRORS_DIR", "/var/www/html/mirrors"))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=repo_root)
    parser.add_argument("--catalog", type=Path, default=mirrors_root / "games/catalog.json")
    parser.add_argument(
        "--launcher-adapters",
        type=Path,
        default=mirrors_root / "games/launcher-adapters.json",
    )
    parser.add_argument(
        "--game-boy-vault",
        type=Path,
        default=mirrors_root / "private-rom-vault/manifest.json",
    )
    parser.add_argument(
        "--game-boy-curated",
        type=Path,
        default=mirrors_root / "private-rom-wave-1/manifest.json",
    )
    parser.add_argument(
        "--board-games",
        type=Path,
        default=mirrors_root / "board-games-wave-1/manifest.json",
    )
    parser.add_argument(
        "--classic-pc",
        type=Path,
        default=mirrors_root / "private-dos-vault/manifest.json",
    )
    parser.add_argument(
        "--native-packages",
        type=Path,
        default=mirrors_root / "games/downloads/native",
    )
    parser.add_argument(
        "--overrides",
        type=Path,
        default=repo_root / "config/canonical-game-overrides.json",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=mirrors_root / "games/canonical-registry.json",
    )
    parser.add_argument(
        "--generated-at",
        default="",
        help="Fixed ISO timestamp for byte-reproducible test builds.",
    )
    parser.add_argument(
        "--skip-installed-package-query",
        action="store_true",
        help="Do not inspect dpkg state; cached package evidence is still collected.",
    )
    return parser.parse_args()


def load_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RegistryError(f"Missing {label}: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RegistryError(f"Invalid JSON in {label}: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RegistryError(f"{label} must be a JSON object: {path}")
    return value


def game_rows(payload: dict[str, Any], label: str) -> list[dict[str, Any]]:
    rows = payload.get("games")
    if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
        raise RegistryError(f"{label} must contain a games array")
    return rows


def require_text(row: dict[str, Any], key: str, label: str) -> str:
    value = row.get(key)
    if not isinstance(value, str) or not value.strip():
        raise RegistryError(f"{label} has no non-empty {key}")
    return value.strip()


def canonical_json_hash(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def generated_at(fixed: str) -> str:
    if fixed:
        return fixed
    epoch = os.environ.get("SOURCE_DATE_EPOCH", "").strip()
    if epoch:
        value = datetime.fromtimestamp(int(epoch), tz=timezone.utc)
    else:
        value = datetime.now(tz=timezone.utc)
    return value.replace(microsecond=0).isoformat().replace("+00:00", "Z")


def public_target(raw: str, default: str) -> str:
    value = str(raw or "").strip()
    if not value:
        return default
    if value.startswith("/mirrors/"):
        return value
    if value.startswith("../"):
        return "/mirrors/" + value[3:]
    if value.startswith("./"):
        return "/mirrors/games/" + value[2:]
    if value.startswith("/"):
        return value
    return default


def catalog_platform(adapter: str) -> str:
    return {
        "browser": "Web browser",
        "browser-emulator": "Browser emulator",
        "hosted-lan": "LAN service / client",
        "desktop-client": "Desktop client",
        "linux-package": "Linux",
        "collection": "Collection",
        "research-shelf": "Research collection",
        "needs-setup": "Desktop setup",
    }.get(adapter, "Platform not audited")


def readiness(
    *,
    playable_now: bool = False,
    local_payload: bool = False,
    local_package: bool = False,
    locally_installed: bool = False,
    qa_verified: bool = False,
    research_only: bool = False,
    state: str = "listed",
) -> dict[str, Any]:
    return {
        "listed": True,
        "playableNow": bool(playable_now),
        "localPayload": bool(local_payload),
        "localPackage": bool(local_package),
        "locallyInstalled": bool(locally_installed),
        "qaVerified": bool(qa_verified),
        "researchOnly": bool(research_only),
        "state": state,
    }


def add_record(records: dict[str, dict[str, Any]], record: dict[str, Any]) -> None:
    record_id = require_text(record, "recordId", "record")
    if record_id in records:
        raise RegistryError(f"Duplicate record ID: {record_id}")
    records[record_id] = record


def apply_record_override(record: dict[str, Any], override: dict[str, Any]) -> None:
    if "platform" in override:
        record["platform"] = str(override["platform"])
    for field in ("launcher", "readiness", "evidence"):
        patch = override.get(field)
        if patch is None:
            continue
        if not isinstance(patch, dict):
            raise RegistryError(f"Record override {field} must be an object")
        record[field].update(patch)


def installed_debian_packages(skip: bool) -> tuple[bool, set[str]]:
    if skip or not shutil.which("dpkg-query"):
        return False, set()
    try:
        output = subprocess.check_output(
            ["dpkg-query", "-W", "-f=${binary:Package}\t${db:Status-Abbrev}\n"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.CalledProcessError):
        return False, set()
    packages: set[str] = set()
    for line in output.splitlines():
        name, separator, status = line.partition("\t")
        if separator and status.startswith("ii "):
            packages.add(name.split(":", 1)[0])
    return True, packages


def asset_rows(payload: dict[str, Any]) -> list[Any]:
    assets = payload.get("assets", [])
    if isinstance(assets, dict):
        return list(assets.values())
    return assets if isinstance(assets, list) else []


def local_asset_paths(manifest_path: Path, payload: dict[str, Any]) -> set[Path]:
    resolved: set[Path] = set()
    for asset in asset_rows(payload):
        if isinstance(asset, str):
            values = [asset]
        elif isinstance(asset, dict):
            values = [asset.get("path"), asset.get("name"), asset.get("url")]
        else:
            values = []
        names: set[str] = set()
        for raw_value in values:
            if not raw_value:
                continue
            value = str(raw_value)
            parsed = urlparse(value)
            decoded_path = unquote(parsed.path)
            name = Path(decoded_path).name
            if name:
                names.add(name)
            if parsed.scheme in {"http", "https"}:
                continue
            candidate = (manifest_path.parent / decoded_path).resolve()
            if candidate.is_file():
                resolved.add(candidate)
            if name:
                direct = (manifest_path.parent / name).resolve()
                if direct.is_file():
                    resolved.add(direct)
        for name in names:
            if any(path.name == name for path in resolved):
                continue
            for candidate in manifest_path.parent.rglob(name):
                if candidate.is_file():
                    resolved.add(candidate.resolve())
    return resolved


def seed_packages(payload: dict[str, Any]) -> list[str]:
    value = payload.get("seedPackages", payload.get("seed_packages", []))
    if isinstance(value, str):
        value = [value]
    if not isinstance(value, list):
        return []
    return sorted({str(item).strip() for item in value if str(item).strip()})


def package_catalog_id(
    slug: str,
    payload: dict[str, Any],
    catalog_ids: set[str],
) -> str:
    candidates: set[str] = set()
    for value in (str(payload.get("id") or "").strip(), slug):
        if not value:
            continue
        for candidate in (value, f"{value}-lan"):
            if candidate in catalog_ids:
                candidates.add(candidate)
    if len(candidates) != 1:
        raise RegistryError(
            f"Native package manifest {slug!r} maps to {sorted(candidates)!r}; "
            "add or correct a structured source ID before regenerating"
        )
    return next(iter(candidates))


def source_summary(
    source_id: str,
    kind: str,
    count: int,
    payload: Any,
    **extra: Any,
) -> dict[str, Any]:
    summary = {
        "sourceCollection": source_id,
        "kind": kind,
        "recordCount": count,
        "contentSha256": canonical_json_hash(payload),
    }
    summary.update(extra)
    return summary


def build_registry(args: argparse.Namespace) -> dict[str, Any]:
    catalog_payload = load_object(args.catalog, "catalog")
    launcher_payload = load_object(args.launcher_adapters, "launcher adapters")
    vault_payload = load_object(args.game_boy_vault, "Game Boy vault")
    curated_payload = load_object(args.game_boy_curated, "curated Game Boy manifest")
    board_payload = load_object(args.board_games, "board-game manifest")
    classic_payload = load_object(args.classic_pc, "Classic PC manifest")
    overrides = load_object(args.overrides, "canonical overrides")

    if overrides.get("schemaVersion") != SCHEMA_VERSION:
        raise RegistryError("Canonical override schemaVersion is unsupported")

    catalog = game_rows(catalog_payload, "catalog")
    vault = game_rows(vault_payload, "Game Boy vault")
    curated = game_rows(curated_payload, "curated Game Boy manifest")
    board = game_rows(board_payload, "board-game manifest")
    classic = game_rows(classic_payload, "Classic PC manifest")
    launcher_games = launcher_payload.get("games", {})
    if not isinstance(launcher_games, dict):
        raise RegistryError("launcher adapters must contain a games object")

    wrapper_rows = overrides.get("collectionWrappers", [])
    if not isinstance(wrapper_rows, list):
        raise RegistryError("collectionWrappers must be an array")
    wrappers = {require_text(row, "catalogId", "collection wrapper"): row for row in wrapper_rows}
    if len(wrappers) != len(wrapper_rows):
        raise RegistryError("collectionWrappers contains duplicate catalog IDs")

    records: dict[str, dict[str, Any]] = {}
    catalog_by_id: dict[str, dict[str, Any]] = {}
    for row in catalog:
        catalog_id = require_text(row, "id", "catalog row")
        if catalog_id in catalog_by_id:
            raise RegistryError(f"Duplicate catalog ID: {catalog_id}")
        catalog_by_id[catalog_id] = row
        title = require_text(row, "title", f"catalog row {catalog_id}")
        audit = launcher_games.get(catalog_id, {})
        if not isinstance(audit, dict):
            audit = {}
        adapter = str(audit.get("adapter") or "")
        qa_status = str(audit.get("qaStatus") or "not-audited")
        is_wrapper = catalog_id in wrappers
        wrapper = wrappers.get(catalog_id, {})
        record_id = f"record:catalog:{catalog_id}"
        add_record(
            records,
            {
                "recordId": record_id,
                "entityId": f"collection:{catalog_id}" if is_wrapper else f"game:catalog:{catalog_id}",
                "entityKind": "collection" if is_wrapper else "title",
                "recordType": "collection-wrapper" if is_wrapper else "launcher-card",
                "sourceCollection": "catalog",
                "sourceRecordId": catalog_id,
                "title": title,
                "platform": "Collection" if is_wrapper else catalog_platform(adapter),
                "collectionMemberships": ["catalog"],
                "launcher": {
                    "adapter": adapter or "not-audited",
                    "target": public_target(str(row.get("path") or ""), f"/mirrors/{catalog_id}/"),
                },
                "readiness": readiness(
                    playable_now=bool(audit.get("readyNow")),
                    qa_verified=qa_status in QA_VERIFIED_LAUNCHER_STATES,
                    research_only=is_wrapper and str(wrapper.get("role")) == "research-shelf",
                    state=str(audit.get("promotionState") or qa_status),
                ),
                "evidence": {
                    "launcherAuditPresent": bool(audit),
                    "qaStatus": qa_status,
                    "launcherTargetObserved": bool(row.get("path")),
                },
                "relationshipToCanonical": "source-record",
            },
        )

    unknown_wrappers = sorted(set(wrappers) - set(catalog_by_id))
    if unknown_wrappers:
        raise RegistryError(f"Collection wrapper IDs not found in catalog: {unknown_wrappers}")

    vault_by_id: dict[str, dict[str, Any]] = {}
    vault_root = args.game_boy_vault.parent
    for row in vault:
        game_id = require_text(row, "id", "Game Boy row")
        if game_id in vault_by_id:
            raise RegistryError(f"Duplicate Game Boy vault ID: {game_id}")
        vault_by_id[game_id] = row
        title = require_text(row, "title", f"Game Boy row {game_id}")
        rom = str(row.get("rom") or "")
        rom_present = bool(rom) and (vault_root / rom).is_file()
        add_record(
            records,
            {
                "recordId": f"record:game-boy-vault:{game_id}",
                "entityId": f"game:game-boy:{game_id}",
                "entityKind": "title",
                "recordType": "title-record",
                "sourceCollection": "game-boy-vault",
                "sourceRecordId": game_id,
                "title": title,
                "platform": str(row.get("system") or "Game Boy"),
                "collectionMemberships": ["game-boy-vault"],
                "launcher": {
                    "adapter": "browser-emulator",
                    "target": f"/mirrors/private-rom-vault/play.html?id={quote(game_id, safe='')}",
                },
                "readiness": readiness(
                    playable_now=rom_present,
                    local_payload=rom_present,
                    local_package=rom_present,
                    state="ready-offline" if rom_present else "rom-missing",
                ),
                "evidence": {
                    "localRomDeclared": bool(rom),
                    "localRomObserved": rom_present,
                    "dedupeKeyPresent": bool(row.get("sha256")),
                },
                "relationshipToCanonical": "source-record",
            },
        )

    for row in board:
        game_id = require_text(row, "id", "board-game row")
        title = require_text(row, "title", f"board-game row {game_id}")
        status = str(row.get("status") or "metadata-only")
        local_implementation = status in {"playable-local", "partial-local", "analog-local"}
        add_record(
            records,
            {
                "recordId": f"record:board-games:{game_id}",
                "entityId": f"game:board:{game_id}",
                "entityKind": "title",
                "recordType": "research-row",
                "sourceCollection": "board-games",
                "sourceRecordId": game_id,
                "title": title,
                "platform": "Tabletop / local implementation" if local_implementation else "Tabletop research",
                "collectionMemberships": ["board-games"],
                "launcher": {
                    "adapter": "local-implementation" if local_implementation else "research-shelf",
                    "target": public_target(str(row.get("url") or ""), "/mirrors/board-games-wave-1/"),
                },
                "readiness": readiness(
                    qa_verified=status == "playable-local",
                    research_only=True,
                    state=status,
                ),
                "evidence": {
                    "sourceStatus": status,
                    "localImplementationLinked": bool(row.get("url")),
                },
                "relationshipToCanonical": "source-record",
            },
        )

    classic_root = args.classic_pc.parent
    for row in classic:
        game_id = require_text(row, "id", "Classic PC row")
        title = require_text(row, "title", f"Classic PC row {game_id}")
        status = str(row.get("status") or "candidate")
        source_state = str(row.get("sourceState") or "source-missing")
        bundle = str(row.get("bundleUrl") or "")
        package = str(row.get("packageUrl") or "")
        bundle_present = bool(bundle) and (classic_root / bundle).is_file()
        package_present = bool(package) and (classic_root / package).is_file()
        packaged = source_state == "packaged" and bundle_present and package_present
        playable = packaged and status in PLAYABLE_CLASSIC_PC_STATES
        add_record(
            records,
            {
                "recordId": f"record:classic-pc:{game_id}",
                "entityId": f"game:classic-pc:{game_id}",
                "entityKind": "title",
                "recordType": "title-record",
                "sourceCollection": "classic-pc",
                "sourceRecordId": game_id,
                "title": title,
                "platform": str(row.get("platform") or "Classic PC"),
                "collectionMemberships": ["classic-pc"],
                "launcher": {
                    "adapter": "browser-emulator" if packaged else "collection",
                    "target": (
                        f"/mirrors/private-dos-vault/play.html?id={quote(game_id, safe='')}"
                        if packaged
                        else "/mirrors/private-dos-vault/"
                    ),
                },
                "readiness": readiness(
                    playable_now=playable,
                    local_payload=packaged,
                    local_package=packaged,
                    qa_verified=status == "smoke-pass",
                    research_only=not packaged,
                    state=status,
                ),
                "evidence": {
                    "sourceStatus": status,
                    "sourceState": source_state,
                    "browserBundleObserved": bundle_present,
                    "downloadPackageObserved": package_present,
                    "qaEvidenceDeclared": bool(row.get("qaReport")),
                },
                "relationshipToCanonical": "source-record",
            },
        )

    group_configs: dict[str, dict[str, Any]] = {}
    assigned_records: set[str] = set()
    groups = overrides.get("canonicalGroups", [])
    if not isinstance(groups, list):
        raise RegistryError("canonicalGroups must be an array")
    for group in groups:
        entity_id = require_text(group, "entityId", "canonical group")
        if entity_id in group_configs:
            raise RegistryError(f"Duplicate canonical group entity ID: {entity_id}")
        relationships = group.get("recordRelationships")
        if not isinstance(relationships, dict) or len(relationships) < 2:
            raise RegistryError(f"Canonical group {entity_id} needs at least two record relationships")
        for record_id, relationship in relationships.items():
            if record_id not in records:
                raise RegistryError(f"Canonical group {entity_id} references unknown {record_id}")
            if record_id in assigned_records:
                raise RegistryError(f"Record appears in more than one canonical group: {record_id}")
            assigned_records.add(record_id)
            records[record_id]["entityId"] = entity_id
            records[record_id]["relationshipToCanonical"] = str(relationship)
        group_configs[entity_id] = group

    curated_seen: set[str] = set()
    for row in curated:
        game_id = require_text(row, "id", "curated Game Boy row")
        if game_id in curated_seen:
            raise RegistryError(f"Duplicate curated Game Boy ID: {game_id}")
        curated_seen.add(game_id)
        vault_row = vault_by_id.get(game_id)
        if vault_row is None:
            raise RegistryError(f"Curated Game Boy ID is absent from the vault: {game_id}")
        curated_sha = str(row.get("sha256") or "")
        vault_sha = str(vault_row.get("sha256") or "")
        if not curated_sha or curated_sha != vault_sha:
            raise RegistryError(f"Curated Game Boy row does not match vault hash: {game_id}")
        vault_record_id = f"record:game-boy-vault:{game_id}"
        add_record(
            records,
            {
                "recordId": f"membership:game-boy-curated:{game_id}",
                "entityId": records[vault_record_id]["entityId"],
                "entityKind": "title",
                "recordType": "collection-membership",
                "sourceCollection": "game-boy-curated",
                "sourceRecordId": game_id,
                "title": require_text(row, "title", f"curated Game Boy row {game_id}"),
                "platform": str(row.get("system") or vault_row.get("system") or "Game Boy"),
                "collectionMemberships": ["game-boy-curated"],
                "launcher": {
                    "adapter": "browser-emulator",
                    "target": f"/mirrors/private-rom-wave-1/play.html?id={quote(game_id, safe='')}",
                },
                "readiness": readiness(state="vault-membership"),
                "evidence": {
                    "sameAsRecordId": vault_record_id,
                    "dedupeEvidence": "source-id-and-sha256-match",
                },
                "relationshipToCanonical": "collection-membership",
            },
        )

    record_overrides = overrides.get("recordOverrides", {})
    if not isinstance(record_overrides, dict):
        raise RegistryError("recordOverrides must be an object")
    for record_id, override in record_overrides.items():
        if record_id not in records:
            raise RegistryError(f"Record override references unknown {record_id}")
        if not isinstance(override, dict):
            raise RegistryError(f"Record override for {record_id} must be an object")
        apply_record_override(records[record_id], override)

    package_manager_observed, installed_packages = installed_debian_packages(
        args.skip_installed_package_query
    )
    native_manifest_rows: list[dict[str, Any]] = []
    package_paths = sorted(args.native_packages.glob("*/manifest.json"))
    for manifest_path in package_paths:
        payload = load_object(manifest_path, f"native package manifest {manifest_path.parent.name}")
        slug = manifest_path.parent.name
        catalog_id = package_catalog_id(slug, payload, set(catalog_by_id))
        catalog_record_id = f"record:catalog:{catalog_id}"
        local_assets = local_asset_paths(manifest_path, payload)
        seeds = seed_packages(payload)
        installed_seeds = sorted(set(seeds) & installed_packages)
        fully_installed = bool(seeds) and package_manager_observed and len(installed_seeds) == len(seeds)
        native_manifest_rows.append(
            {
                "slug": slug,
                "manifest": payload,
                "localAssetCount": len(local_assets),
                "declaredSeedPackageCount": len(seeds),
                "installedSeedPackageCount": len(installed_seeds),
            }
        )
        add_record(
            records,
            {
                "recordId": f"evidence:native-package:{slug}",
                "entityId": records[catalog_record_id]["entityId"],
                "entityKind": "title",
                "recordType": "package-evidence",
                "sourceCollection": "native-package-shelves",
                "sourceRecordId": str(payload.get("id") or slug),
                "title": str(payload.get("title") or catalog_by_id[catalog_id].get("title") or catalog_id),
                "platform": "Native package cache",
                "collectionMemberships": ["native-package-shelves"],
                "launcher": {
                    "adapter": "package-download",
                    "target": f"/mirrors/games/downloads/native/{quote(slug, safe='')}/",
                },
                "readiness": readiness(
                    local_payload=bool(local_assets),
                    local_package=bool(local_assets),
                    locally_installed=fully_installed,
                    state="cached" if local_assets else "manifest-only",
                ),
                "evidence": {
                    "catalogRecordId": catalog_record_id,
                    "localAssetCount": len(local_assets),
                    "declaredSeedPackageCount": len(seeds),
                    "installedSeedPackageCount": len(installed_seeds),
                    "packageManagerObserved": package_manager_observed,
                },
                "relationshipToCanonical": "package-evidence",
            },
        )

    relationships: list[dict[str, Any]] = []
    review_flags: dict[str, list[dict[str, Any]]] = defaultdict(list)
    review_rows = overrides.get("reviewRelationships", [])
    if not isinstance(review_rows, list):
        raise RegistryError("reviewRelationships must be an array")
    for row in review_rows:
        relationship_id = require_text(row, "id", "review relationship")
        record_a = require_text(row, "recordA", relationship_id)
        record_b = require_text(row, "recordB", relationship_id)
        if record_a not in records or record_b not in records:
            raise RegistryError(f"{relationship_id} references an unknown record")
        entity_a = records[record_a]["entityId"]
        entity_b = records[record_b]["entityId"]
        if row.get("keepSeparate") and entity_a == entity_b:
            raise RegistryError(f"{relationship_id} must remain separate but was merged")
        relationship = {
            "relationshipId": relationship_id,
            "type": require_text(row, "type", relationship_id),
            "entityA": entity_a,
            "entityB": entity_b,
            "recordA": record_a,
            "recordB": record_b,
            "reason": str(row.get("reason") or "Manual review required."),
            "reviewRequired": bool(row.get("reviewRequired")),
            "keptSeparate": bool(row.get("keepSeparate")),
        }
        relationships.append(relationship)
        if relationship["reviewRequired"]:
            review_flags[entity_a].append(
                {
                    "relationshipId": relationship_id,
                    "type": relationship["type"],
                    "relatedEntityId": entity_b,
                }
            )
            review_flags[entity_b].append(
                {
                    "relationshipId": relationship_id,
                    "type": relationship["type"],
                    "relatedEntityId": entity_a,
                }
            )

    records_by_entity: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for record in records.values():
        records_by_entity[record["entityId"]].append(record)

    entities: list[dict[str, Any]] = []
    for entity_id, entity_records in sorted(records_by_entity.items()):
        kinds = {record["entityKind"] for record in entity_records}
        if len(kinds) != 1:
            raise RegistryError(f"Entity {entity_id} mixes title and collection records")
        kind = next(iter(kinds))
        group = group_configs.get(entity_id, {})
        title_records = [record for record in entity_records if record["recordType"] in TITLE_RECORD_TYPES]
        if kind == "title" and not title_records:
            raise RegistryError(f"Title entity {entity_id} has no title-bearing source record")
        canonical_title = str(
            group.get("canonicalTitle")
            or sorted(title_records or entity_records, key=lambda item: item["recordId"])[0]["title"]
        )
        aliases = sorted(
            {
                record["title"]
                for record in title_records
                if record["title"] and record["title"] != canonical_title
            },
            key=str.casefold,
        )
        launcher_targets = []
        for record in entity_records:
            target = record["launcher"].get("target")
            if not target:
                continue
            launcher_targets.append(
                {
                    "target": target,
                    "adapter": record["launcher"].get("adapter", "unknown"),
                    "readyNow": bool(record["readiness"]["playableNow"]),
                    "recordId": record["recordId"],
                }
            )
        launcher_targets = sorted(
            {json.dumps(item, sort_keys=True): item for item in launcher_targets}.values(),
            key=lambda item: (
                not item["readyNow"],
                item["adapter"] == "package-download",
                item["target"],
                item["recordId"],
            ),
        )
        title_readiness = [record["readiness"] for record in title_records]
        entity_readiness = {
            "playableNow": any(record["readiness"]["playableNow"] for record in entity_records),
            "localPayload": any(record["readiness"]["localPayload"] for record in entity_records),
            "localPackage": any(record["readiness"]["localPackage"] for record in entity_records),
            "locallyInstalled": any(record["readiness"]["locallyInstalled"] for record in entity_records),
            "qaVerified": any(record["readiness"]["qaVerified"] for record in entity_records),
            "researchOnly": bool(title_readiness) and all(value["researchOnly"] for value in title_readiness),
        }
        entities.append(
            {
                "entityId": entity_id,
                "kind": kind,
                "canonicalTitle": canonical_title,
                "aliases": aliases,
                "platforms": sorted(
                    {record["platform"] for record in entity_records if record.get("platform")},
                    key=str.casefold,
                ),
                "collectionMemberships": sorted(
                    {
                        membership
                        for record in entity_records
                        for membership in record["collectionMemberships"]
                    }
                ),
                "recordIds": sorted(record["recordId"] for record in entity_records),
                "recordRelationships": sorted(
                    [
                        {
                            "recordId": record["recordId"],
                            "type": record["relationshipToCanonical"],
                        }
                        for record in entity_records
                    ],
                    key=lambda item: item["recordId"],
                ),
                "launcherTargets": launcher_targets,
                "primaryLauncher": launcher_targets[0] if launcher_targets else None,
                "readiness": entity_readiness,
                "canonicalConfidence": str(group.get("confidence") or "source-record"),
                "canonicalNote": str(group.get("note") or ""),
                "reviewFlags": sorted(
                    review_flags.get(entity_id, []),
                    key=lambda item: item["relationshipId"],
                ),
            }
        )

    title_entities = [entity for entity in entities if entity["kind"] == "title"]
    collection_entities = [entity for entity in entities if entity["kind"] == "collection"]
    raw_title_records = [
        record
        for record in records.values()
        if record["recordType"] in TITLE_RECORD_TYPES and record["entityKind"] == "title"
    ]
    unresolved_duplicates = [
        relationship
        for relationship in relationships
        if relationship["type"] == "possible-duplicate" and relationship["reviewRequired"]
    ]
    metrics = {
        "distinctCanonicalTitles": len(title_entities),
        "canonicalCollectionWrappers": len(collection_entities),
        "canonicalEntities": len(entities),
        "topLevelLauncherCards": len(catalog),
        "playableNowTitles": sum(entity["readiness"]["playableNow"] for entity in title_entities),
        "locallyPackagedTitles": sum(entity["readiness"]["localPackage"] for entity in title_entities),
        "localPackageRecords": sum(record["readiness"]["localPackage"] for record in records.values()),
        "locallyInstalledNativeTitles": sum(
            entity["readiness"]["locallyInstalled"] for entity in title_entities
        ),
        "qaVerifiedTitles": sum(entity["readiness"]["qaVerified"] for entity in title_entities),
        "collectionAndResearchRows": sum(
            record["recordType"] in {"collection-wrapper", "research-row"}
            for record in records.values()
        ),
        "researchRows": sum(record["recordType"] == "research-row" for record in records.values()),
        "curatedGameBoyMemberships": sum(
            record["recordType"] == "collection-membership" for record in records.values()
        ),
        "resolvedDuplicateTitleRecords": len(raw_title_records) - len(title_entities),
        "unresolvedPossibleDuplicates": len(unresolved_duplicates),
        "manualReviewRelationships": sum(
            relationship["reviewRequired"] for relationship in relationships
        ),
        "nativePackageManifests": len(package_paths),
        "totalSourceRecords": len(records),
    }

    collection_wrappers = []
    for catalog_id, row in sorted(wrappers.items()):
        record_id = f"record:catalog:{catalog_id}"
        collection_wrappers.append(
            {
                "entityId": records[record_id]["entityId"],
                "catalogId": catalog_id,
                "title": records[record_id]["title"],
                "role": str(row.get("role") or "collection"),
                "memberCollections": sorted(str(value) for value in row.get("memberCollections", [])),
                "launcherRecordId": record_id,
            }
        )

    sources = [
        source_summary("catalog", "top-level-launcher-cards", len(catalog), catalog_payload),
        source_summary("game-boy-vault", "title-records", len(vault), vault_payload),
        source_summary(
            "game-boy-curated",
            "membership-records",
            len(curated),
            curated_payload,
            dedupedAgainst="game-boy-vault",
        ),
        source_summary("board-games", "research-rows", len(board), board_payload),
        source_summary("classic-pc", "title-records", len(classic), classic_payload),
        source_summary(
            "native-package-shelves",
            "package-evidence-records",
            len(package_paths),
            native_manifest_rows,
            packageManagerObserved=package_manager_observed,
        ),
    ]

    digest_material = {
        "catalog": catalog_payload,
        "launcherAdapters": launcher_payload,
        "gameBoyVault": vault_payload,
        "gameBoyCurated": curated_payload,
        "boardGames": board_payload,
        "classicPc": classic_payload,
        "nativePackages": native_manifest_rows,
        "overrides": overrides,
    }
    registry = {
        "schemaVersion": SCHEMA_VERSION,
        "generatedAt": generated_at(args.generated_at),
        "inputDigestSha256": canonical_json_hash(digest_material),
        "definitions": {
            "entityId": "Stable canonical identity. Title entities group only confirmed aliases or editions; collection wrappers use separate collection identities.",
            "recordId": "Stable identity for one source row, collection membership, launcher card, or package-evidence observation.",
            "playableNow": "At least one direct player launcher is locally present and not blocked. Package-only native hubs do not qualify.",
            "localPackage": "A ROM, Classic PC package/bundle, or native package-shelf payload declared by a manifest was observed locally. This does not imply playability.",
            "locallyInstalled": "All declared seed packages for at least one native package manifest are installed on this VM. Cache-only shelves do not qualify.",
            "qaVerified": "A structured gameplay/service smoke state, a board playable-local state, or an explicit reviewed QA override exists. Inferred readiness does not qualify.",
            "reviewFlag": "The records remain separate until an operator confirms whether they are aliases, editions, or merely related games.",
        },
        "metricDefinitions": {
            "distinctCanonicalTitles": "Title entities after confirmed aliases and editions are grouped. Collection wrappers, curated membership records, and package-evidence records are excluded. Review-flagged pairs remain separate, so this is not labelled unique.",
            "canonicalCollectionWrappers": "Top-level launcher cards explicitly modelled as collections or research shelves rather than games.",
            "canonicalEntities": "Canonical title entities plus separately modelled collection-wrapper entities.",
            "topLevelLauncherCards": "Navigation cards in catalog.json, including collection wrappers. This is not the complete inventory count.",
            "playableNowTitles": "Canonical title entities with at least one direct ready launcher. Nested Game Boy and non-blocked packaged Classic PC launchers are included.",
            "locallyPackagedTitles": "Canonical title entities with an observed local ROM, Classic PC bundle/package, or native package-shelf payload.",
            "localPackageRecords": "Source/evidence records with an observed local package payload before canonical edition grouping.",
            "locallyInstalledNativeTitles": "Canonical title entities whose manifest-declared native seed package set is currently installed on this VM.",
            "qaVerifiedTitles": "Canonical title entities with structured QA evidence under the qaVerified definition.",
            "collectionAndResearchRows": "Collection-wrapper launcher records plus board-game research rows; this is a row count, not a game count.",
            "researchRows": "Rows from the board-game research collection, including rows that link to a local implementation.",
            "curatedGameBoyMemberships": "Curated subset memberships that point to existing Game Boy vault entities and do not create titles.",
            "resolvedDuplicateTitleRecords": "Raw title-bearing source rows absorbed by confirmed canonical groups.",
            "unresolvedPossibleDuplicates": "Review-required possible-duplicate relationships kept as separate canonical titles.",
            "manualReviewRelationships": "All review-required relationships, including analog implementations that are not duplicate candidates.",
            "nativePackageManifests": "Direct normalized native package manifests observed on the local package shelf.",
            "totalSourceRecords": "All launcher, title, research, membership, and package-evidence records represented in this registry.",
        },
        "metrics": metrics,
        "sources": sources,
        "collectionWrappers": collection_wrappers,
        "relationships": sorted(relationships, key=lambda item: item["relationshipId"]),
        "entities": entities,
        "records": [records[record_id] for record_id in sorted(records)],
    }
    validate_registry(registry)
    return registry


def validate_registry(registry: dict[str, Any]) -> None:
    entities = registry["entities"]
    records = registry["records"]
    entity_ids = [entity["entityId"] for entity in entities]
    record_ids = [record["recordId"] for record in records]
    if len(entity_ids) != len(set(entity_ids)):
        raise RegistryError("Generated duplicate entity IDs")
    if len(record_ids) != len(set(record_ids)):
        raise RegistryError("Generated duplicate record IDs")
    known_entities = set(entity_ids)
    for record in records:
        if record["entityId"] not in known_entities:
            raise RegistryError(f"Record references unknown entity: {record['recordId']}")
        target = record["launcher"].get("target", "")
        if target and not target.startswith("/mirrors/"):
            raise RegistryError(f"Non-local launcher target in {record['recordId']}: {target}")
    encoded = json.dumps(registry, ensure_ascii=True, sort_keys=True)
    for forbidden in ("http://", "https://", "/home/", "/var/www/"):
        if forbidden in encoded:
            raise RegistryError(f"Public registry contains forbidden operator/external text: {forbidden}")


def write_registry(path: Path, registry: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = json.dumps(registry, ensure_ascii=True, indent=2) + "\n"
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(output, encoding="utf-8")
    os.chmod(temporary, 0o644)
    os.replace(temporary, path)


def main() -> int:
    args = parse_args()
    try:
        registry = build_registry(args)
        write_registry(args.output, registry)
    except RegistryError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(registry["metrics"], sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
