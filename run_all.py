"""Runs the SQL in order, exports every result table to results/ and draws the charts.

Usage:  python load.py      (once, types the raw log)
        python run_all.py   (everything else)
"""
import csv
import sqlite3
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).parent
con = sqlite3.connect(HERE / "incidents.db")
for f in sorted((HERE / "sql").glob("*.sql")):
    con.executescript(f.read_text(encoding="utf-8"))
    print("ran", f.name)
con.commit()

for table in ["rule_results", "a_priority", "a_handoffs", "a_pingpong", "a_groups", "a_reassign_check", "kpi_summary", "a_categories"]:
    cur = con.execute(f"SELECT * FROM {table}")
    with open(HERE / "results" / f"{table}.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow([d[0] for d in cur.description])
        w.writerows(cur.fetchall())
    print("exported", table)

NAVY, ORANGE, GREY = "#1f3a5f", "#e8892b", "#9aa5b1"
plt.rcParams.update({"font.family": "Calibri", "font.size": 11})

# Figure 1: handoffs vs SLA breach and median resolution time (priority 3).
rows = con.execute("SELECT handoff_band, incidents, median_hours, sla_breach_pct FROM a_handoffs").fetchall()
bands = [r[0] for r in rows]
fig, ax = plt.subplots(figsize=(8, 4.2))
bars = ax.bar(bands, [r[3] for r in rows], color=NAVY)
for b, r in zip(bars, rows):
    ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1.5, f"{r[3]:.0f} %", ha="center", color=NAVY)
ax.set_ylim(0, 100)
ax.set_xlabel("Handoffs between support groups")
ax.set_ylabel("SLA breached, % of incidents", color=NAVY)
ax2 = ax.twinx()
ax2.plot(bands, [r[2] for r in rows], color=ORANGE, marker="o", linewidth=2)
for x, r in zip(bands, rows):
    ax2.annotate(f"{r[2]:.0f} h", (x, r[2]), textcoords="offset points", xytext=(0, 8), ha="center", color=ORANGE)
ax2.set_ylabel("Median hours to resolve", color=ORANGE)
ax2.set_ylim(0, max(r[2] for r in rows) * 1.7)
ax.set_title("Every handoff adds time and SLA risk (priority 3, n = %d)" % sum(r[1] for r in rows), loc="left")
for a in (ax, ax2):
    a.spines["top"].set_visible(False)
fig.tight_layout()
fig.savefig(HERE / "figures" / "01_handoffs_sla.png", dpi=200)

# Figure 1, Czech labels (for the Czech project card).
rows = con.execute("SELECT handoff_band, incidents, median_hours, sla_breach_pct FROM a_handoffs").fetchall()
bands = [r[0] for r in rows]
fig, ax = plt.subplots(figsize=(8, 4.2))
bars = ax.bar(bands, [r[3] for r in rows], color=NAVY)
for b, r in zip(bars, rows):
    ax.text(b.get_x() + b.get_width() / 2, b.get_height() + 1.5, f"{r[3]:.0f} %", ha="center", color=NAVY)
ax.set_ylim(0, 100)
ax.set_xlabel("Počet předání mezi skupinami podpory")
ax.set_ylabel("Porušené SLA, % incidentů", color=NAVY)
ax2 = ax.twinx()
ax2.plot(bands, [r[2] for r in rows], color=ORANGE, marker="o", linewidth=2)
for x, r in zip(bands, rows):
    ax2.annotate(f"{r[2]:.0f} h", (x, r[2]), textcoords="offset points", xytext=(0, 8), ha="center", color=ORANGE)
ax2.set_ylabel("Medián hodin do vyřešení", color=ORANGE)
ax2.set_ylim(0, max(r[2] for r in rows) * 1.7)
ax.set_title("Každé předání přidává čas i riziko SLA (priorita 3, n = %d)" % sum(r[1] for r in rows), loc="left")
for a_ in (ax, ax2):
    a_.spines["top"].set_visible(False)
fig.tight_layout()
fig.savefig(HERE / "figures" / "01_handoffs_sla_cz.png", dpi=200)

# Figure 2: ping-pong against forward-only paths at the same number of handoffs.
rows = con.execute("SELECT handoffs, path, incidents, median_hours, sla_breach_pct FROM a_pingpong").fetchall()
fig, axes = plt.subplots(1, 2, figsize=(8, 3.8))
for ax, idx, title, unit in [(axes[0], 4, "SLA breached", "%"), (axes[1], 3, "Median hours to resolve", "h")]:
    for k, h in enumerate((2, 3)):
        pair = [r for r in rows if r[0] == h]
        for j, r in enumerate(pair):
            x = k * 3 + j
            col = GREY if r[1].startswith("moved") else ORANGE
            ax.bar(x, r[idx], color=col, label=r[1] if k == 0 else None)
            ax.text(x, r[idx] * 1.02, f"{r[idx]:.0f} {unit}", ha="center", fontsize=9)
    ax.set_xticks([0.5, 3.5])
    ax.set_xticklabels(["2 handoffs", "3 handoffs"])
    ax.set_title(title, loc="left")
    ax.set_ylim(0, max(r[idx] for r in rows) * 1.3)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
axes[0].legend(fontsize=8, frameon=False, loc="upper left")
fig.suptitle("Going back to an earlier group adds little once the number of handoffs is the same", x=0.01, ha="left", fontsize=11)
fig.tight_layout()
fig.savefig(HERE / "figures" / "02_ping_pong.png", dpi=200)

# Figure 3: rule check results.
rows = con.execute("SELECT rule_id, rule, checked, violations FROM rule_results").fetchall()
fig, ax = plt.subplots(figsize=(8, 4.6))
pct = [100.0 * r[3] / r[2] if r[2] else 0 for r in rows]
ys = range(len(rows))[::-1]
ax.barh(list(ys), pct, color=[GREY if p == 0 else ORANGE for p in pct])
ax.set_yticks(list(ys))
ax.set_yticklabels([f"{r[0]}  {r[1]}" for r in rows], fontsize=9)
for y, p, r in zip(ys, pct, rows):
    ax.text(p + 0.3, y, f"{r[3]:,} ({p:.1f} %)".replace(",", " "), va="center", fontsize=9)
ax.set_xlabel("Share of checked cases that break the rule, %")
ax.set_xlim(0, max(pct) * 1.4 + 1)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)
ax.set_title("ITIL process and data rules, checked in SQL", loc="left")
fig.tight_layout()
fig.savefig(HERE / "figures" / "03_rules.png", dpi=200)
print("figures written")
