"""Independent check: recounts the headline numbers straight from the raw CSV,
with plain Python and no SQL, so an error in the SQL logic would show up as a
mismatch with results/a_handoffs.csv and results/a_pingpong.csv."""
import csv
import statistics
from collections import defaultdict
from datetime import datetime

fmt = "%d/%m/%Y %H:%M"
events = defaultdict(list)
with open("data/incident_event_log.csv", encoding="utf-8") as f:
    for i, r in enumerate(csv.DictReader(f)):
        if r["incident_state"] != "-100":
            events[r["number"]].append((int(r["sys_mod_count"]), datetime.strptime(r["sys_updated_at"], fmt), i, r))

bands = defaultdict(lambda: [0, 0, []])
pingpong = defaultdict(lambda: [0, 0])
no_resolution = 0
for evs in events.values():
    evs.sort(key=lambda e: e[:3])
    last = evs[-1][3]
    no_resolution += last["resolved_at"] == "?"
    path = []
    for e in evs:
        g = e[3]["assignment_group"]
        if g != "?" and (not path or path[-1] != g):
            path.append(g)
    handoffs = max(len(path) - 1, 0)
    bounced = any(path[k] in path[:k] for k in range(len(path)))
    if last["priority"].startswith("3") and last["resolved_at"] != "?":
        hours = (datetime.strptime(last["resolved_at"], fmt) - datetime.strptime(last["opened_at"], fmt)).total_seconds() / 3600
        b = "4+" if handoffs >= 4 else str(handoffs)
        bands[b][0] += 1
        bands[b][1] += last["made_sla"] == "false"
        bands[b][2].append(hours)
        if handoffs in (2, 3):
            pingpong[(handoffs, bounced)][0] += 1
            pingpong[(handoffs, bounced)][1] += last["made_sla"] == "false"

print("incidents", len(events), "| closed without resolution time", no_resolution)
for b in sorted(bands):
    n, breached, hours = bands[b]
    print(f"handoffs {b}: {n} incidents, median {statistics.median(hours):.1f} h, SLA breached {100 * breached / n:.1f} %")
for (h, bounced), (n, breached) in sorted(pingpong.items()):
    print(f"{h} handoffs, {'back to earlier group' if bounced else 'forward only'}: {n}, SLA breached {100 * breached / n:.1f} %")
