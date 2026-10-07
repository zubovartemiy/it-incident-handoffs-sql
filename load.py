"""Step 0: turn the raw UCI event log into a typed `events` table.

Reads data/incident_event_log.csv (UCI #498, CC BY 4.0) and creates
incidents.db from scratch. The CSV stores dates as d/m/yyyy hh:mm text and
missing values as "?". This script only types the data; every rule check and
analysis after this is plain SQL in sql/.
"""
import csv
import sqlite3
from datetime import datetime
from pathlib import Path

HERE = Path(__file__).parent
CSV = HERE / "data" / "incident_event_log.csv"
DB = HERE / "incidents.db"


def ts(v):
    """'29/2/2016 01:16' -> '2016-02-29 01:16'; '?' -> None."""
    if v in (None, "?", ""):
        return None
    return datetime.strptime(v, "%d/%m/%Y %H:%M").strftime("%Y-%m-%d %H:%M")


def txt(v):
    return None if v in (None, "?", "") else v


def num(v):
    """'2 - Medium' -> 2, '3' -> 3, '?' -> None."""
    v = txt(v)
    return None if v is None else int(v.split(" ")[0])


if not CSV.exists():
    raise SystemExit(f"Missing {CSV}. Download it from https://archive.ics.uci.edu/dataset/498")

rows, skipped = [], 0
with open(CSV, newline="", encoding="utf-8") as f:
    reader = csv.reader(f)
    next(reader)  # header
    for r in reader:
        (number, state, active, reas, reopen, mods, sla, _caller, _opened_by, opened_at,
         _cby, _cat, _uby, upd_at, contact, _loc, cat, subcat, _sym, _ci, impact, urgency,
         prio, group, assigned, know, prio_conf, _notify, problem, rfc, vendor, _caused,
         code, res_by, res_at, closed_at) = r
        if state == "-100":
            skipped += 1
            continue
        rows.append((number, state, active == "true", int(reas), int(reopen), int(mods),
                     sla == "true", contact, txt(cat), txt(subcat), num(impact), num(urgency),
                     num(prio), txt(group), txt(assigned), know == "true", prio_conf == "true",
                     txt(problem), txt(rfc), txt(vendor), txt(code), txt(res_by),
                     ts(opened_at), ts(upd_at), ts(res_at), ts(closed_at)))

con = sqlite3.connect(DB)
con.executescript("DROP TABLE IF EXISTS events;")
con.execute("""
CREATE TABLE events (
    number TEXT, incident_state TEXT, active INTEGER,
    reassignment_count INTEGER, reopen_count INTEGER, sys_mod_count INTEGER,
    made_sla INTEGER, contact_type TEXT, category TEXT, subcategory TEXT,
    impact INTEGER, urgency INTEGER, priority INTEGER,
    assignment_group TEXT, assigned_to TEXT, knowledge INTEGER,
    u_priority_confirmation INTEGER, problem_id TEXT, rfc TEXT, vendor TEXT,
    closed_code TEXT, resolved_by TEXT,
    opened_at TEXT, sys_updated_at TEXT, resolved_at TEXT, closed_at TEXT
)""")
con.executemany(f"INSERT INTO events VALUES ({','.join('?' * 26)})", rows)
con.commit()
print(f"events: {len(rows)} rows typed, {skipped} rows with state '-100' skipped")
