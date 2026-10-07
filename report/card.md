# What does a handoff cost a service desk?

**SQL analysis of a public IT incident log (ServiceNow export, 24 918 incidents, UCI no. 498).** Personal project, October 2026.

**Question.** How are handoffs between support groups related to resolution time and SLA breaches, and is ping-pong worse than a handoff to a new group?

**What I did.** Typed the raw event log, then in SQL (window functions, CTEs): rebuilt each incident's path through support groups, compared resolution time and SLA breaches by number of handoffs, compared ping-pong with forward-only paths at the same number of handoffs, and wrote 11 SQL checks of incident-management process logic and data quality.

**Results.**
- Solved by the first group: median 1 hour, 26 % SLA breached. With 4+ handoffs: 282 hours, 81 % breached (priority 3, 21 644 incidents with a recorded group).
- Ping-pong looks worse mainly because bounced incidents have more handoffs; at the same count the differences become small and are not consistent.
- The tool enforces its own logic (priority matrix, timestamps, SLA flag are clean), but 6.2 % of closed incidents have no resolution time.

**What it means.** First-group resolution goes with the shortest resolution times; getting incidents to the right group sooner looks more useful than banning returns; closure data should be mandatory.

**Tools.** SQLite (SQL), Python for loading and charts.

---

*Czech, for interviews:* Analyzoval jsem veřejný log incidentů ze ServiceNow, 24 918 incidentů. V SQL jsem rekonstruoval, přes které skupiny incident prošel, a ověřil 11 kontrol procesu řízení incidentů a kvality dat. Čím více předání mezi skupinami, tím delší řešení a vyšší podíl porušených SLA: bez předání je medián hodina, se čtyřmi a více předáními přes 280 hodin.
