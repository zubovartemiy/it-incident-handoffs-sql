# What does a handoff cost a service desk?

SQL analysis of a public IT incident log: 141,712 events, 24,918 incidents from a ServiceNow instance of an IT company (UCI Machine Learning Repository no. 498, CC BY 4.0). Personal project by Artemiy Zubov, October 2026.

![Handoffs and SLA](figures/01_handoffs_sla.png)

## Findings
- **More handoffs go with longer resolution and more SLA breaches.** Priority 3 incidents solved by the first group: median 1 hour, 26 % SLA breached. With 4 or more handoffs: 282 hours, 81 %.
- **Handoff count is a stronger signal than ping-pong.** A return to an earlier group looks harmful mainly because those incidents have more handoffs; compared at the same number of handoffs, the differences become small and are not consistent. This suggests that getting the incident to the right group sooner matters more.
- **The tool keeps its own logic clean; people's data entry does not.** 11 incident-management process and data-quality checks in SQL: the priority matrix, timestamps and SLA flag are clean, but 6.2 % of closed incidents carry no resolution time and drop out of reports based on it.
- **Verified twice.** The headline numbers are recounted from the raw file without SQL (`verify.py`); all match.

## How a service desk could use this
- `sql/04_kpi.sql` is a ready KPI pack: first-group resolution, handoffs, SLA, reopen rate, data completeness, knowledge-base use, plus a ranking of categories that are passed on most often.
- `sql/02_rules.sql` is a set of data-quality checks that can run on any ServiceNow-style export.

## Run it
1. Download `incident_event_log.csv` from https://archive.ics.uci.edu/dataset/498 into `data/`.
2. `python load.py` (reads the CSV and creates `incidents.db`), `python run_all.py` (all SQL, results, charts), `python verify.py` (independent recount).

Requirements: Python 3 with matplotlib; SQLite 3.25+ (window functions).

Optional: `python make_cards.py` rebuilds the one-page project cards; it needs Windows, Microsoft Word, `python-docx` and `pywin32`.

## Files
- `sql/01_incidents.sql` - incidents and their path through support groups
- `sql/02_rules.sql` - 11 process and data-quality checks
- `sql/03_analysis.sql` - handoff and ping-pong comparisons, group profile
- `sql/04_kpi.sql` - KPI pack and category ranking
- `results/` - every result table as CSV; `figures/` - charts
- `report/report.md` - full report with method and limits; `report/*.pdf` - one-page cards in English and Czech
