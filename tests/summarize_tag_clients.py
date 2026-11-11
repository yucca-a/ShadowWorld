"""Summarize native tag diagnostics without treating mere completion as a pass."""
from pathlib import Path
import argparse
from collections import Counter
import json


def persistent(path):
    raw = path.read_bytes()
    if not raw.startswith(b"KLEI     1 "):
        raise ValueError(f"Unexpected persistent header: {path}")
    return json.loads(raw[11:])


def summarize(cluster):
    report = json.loads((cluster / "tag-clients-result.json").read_text(encoding="utf-8"))
    result = {"cluster": str(cluster.resolve()), "status": report["status"],
              "options": report["options"], "rounds": [], "schemas": [], "recipes": [],
              "mismatches": 0, "pressure_missing": [], "limitations": []}
    for client in report.get("clients", []):
        snapshots = []
        for row in client["events"]:
            if row["kind"] == "client_snapshot":
                result["mismatches"] += len(row.get("mismatches", []))
                snapshots.append(row)
            elif row["kind"] == "client_finished":
                full = [s for s in snapshots if s["players"] >= report["options"]["clients"]][-8:]
                store = next((s["gold"] == 0 for s in full if s.get("stable") == 5), None)
                result["rounds"].append({"log": Path(client["log"]).name, "index": row["index"],
                    "crafted": row.get("builds", 0) > 0 and row.get("held") == "spear",
                    "stored": store, "final_gold": row["gold"],
                    "stable_snapshots": len(full)})
                snapshots = []
    for directory in sorted(cluster.glob("client-[123]")):
        own_uid = next((r["userid"] for c in report.get("clients", [])
                        if Path(c["log"]).stem == directory.name
                        for r in c["events"] if r["kind"] == "client_ready"), None)
        for file in directory.glob("**/tag_schema_client_*"):
            uid = file.name.split("client_", 1)[1]
            server = list(cluster.glob("config/**/tag_schema_server_" + uid))
            if not server:
                continue
            observed, expected = persistent(file), persistent(server[0])
            entry = {"userid": uid}
            for part in ("body", "classified"):
                client_vars = Counter((v["name"], v["kind"]) for v in observed.get(part, []))
                server_vars = Counter((v["name"], v["kind"]) for v in expected.get(part, []))
                entry[part + "_matches"] = client_vars == server_vars
                entry[part + "_count"] = sum(client_vars.values())
                entry[part + "_duplicates"] = [list(k) for k, n in client_vars.items() if n > 1]
            result["schemas"].append(entry)
        for file in directory.glob("**/tag_recipes_client_*"):
            uid = file.name.split("client_", 1)[1]
            server = list(cluster.glob("config/**/tag_recipes_server_" + uid))
            if server:
                observed, expected = persistent(file), persistent(server[0])
                differences = [name for name in sorted(set(observed) | set(expected))
                               if observed.get(name) != expected.get(name)]
                result["recipes"].append({"userid": uid, "count": len(observed), "differences": differences})
        missing = set()
        for file in directory.glob("**/tag_audit_[123]_*"):
            data = persistent(file)
            for player in data.get("server", {}).get("players", []):
                # Other clients can observe a new arrival before its delayed
                # fixture preparation. The owner's ready signal follows that
                # preparation, so only its own snapshots prove retention.
                if player["userid"] != own_uid:
                    continue
                for i, present in enumerate(player.get("pressure", []), 1):
                    if not present:
                        missing.add((player["userid"], i))
        result["pressure_missing"].extend([list(v) for v in sorted(missing)])
    if any(r["stored"] is None for r in result["rounds"]):
        result["limitations"].append("Older fixture: quick-store result not validated")
    if not result["recipes"]:
        result["limitations"].append("Older fixture: only selected recipe permissions were compared")
    result["observed_failure"] = bool(result["mismatches"] or result["pressure_missing"]
        or any(not r["crafted"] or r["stored"] is False for r in result["rounds"])
        or any(r["differences"] for r in result["recipes"])
        or any(not r["body_matches"] or not r["classified_matches"] for r in result["schemas"]))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cluster", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = summarize(args.cluster)
    output = args.output or args.cluster / "tag-diagnostics-summary.json"
    output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
