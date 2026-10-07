# IT incident log: handoffs, SLA and ITIL rules in SQL

Personal project, October 2026. Public data: UCI Machine Learning Repository no. 498 (CC BY 4.0), 141 712 events, 24 918 incidents from a ServiceNow instance.

**Main findings**
- Each handoff between support groups costs time and SLA: priority 3 incidents solved by the first group take a median of 1 hour and breach the SLA in 26 % of cases; with 4 or more handoffs, 282 hours and 81 %.
- Ping-pong (going back to an earlier group) is not worse in itself: at the same number of handoffs the results are almost equal. The lever is routing to the right group sooner.
- 11 ITIL process and data rules checked in SQL; the biggest gap: 6.2 % of closed incidents have no resolution time.

**Files**
- `load.py` - types the raw log; `run_all.py` - runs the SQL, exports results, draws charts
- `sql/01_incidents.sql` - incidents and their path through groups
- `sql/02_rules.sql` - the 11 rule checks
- `sql/03_analysis.sql` - handoff and ping-pong comparisons
- `results/` - every result table as CSV; `figures/` - charts
- `verify.py` - independent recount of the headline numbers from the raw CSV (output in `results/verify_output.txt`)
- `make_cards.py` - builds the one-page cards
- `report/report.md` - full report; `report/Project_card_IT_incidents_EN.pdf` and `report/Projektova_karta_IT_incidenty_CZ.pdf` - one-page cards; `report/publish_drafts.md` - LinkedIn, CV and GitHub drafts

Data: download `incident_event_log.csv` from https://archive.ics.uci.edu/dataset/498 into `data/`, then run `python load.py` and `python run_all.py`.
