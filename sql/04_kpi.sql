-- 05. A reusable service desk KPI pack: the figures a team lead would watch every
-- month. Each KPI is one row, so the same query can feed a dashboard.

DROP TABLE IF EXISTS kpi_summary;
CREATE TABLE kpi_summary (kpi TEXT, value REAL, unit TEXT, how_computed TEXT);

INSERT INTO kpi_summary
SELECT 'Incidents', COUNT(*), 'count', 'all incidents in the log' FROM inc;

INSERT INTO kpi_summary
SELECT 'Resolved by the first group', ROUND(100.0 * AVG(handoffs = 0), 1), '%',
       'no change of assignment group in the audit trail' FROM inc;

INSERT INTO kpi_summary
SELECT 'Average handoffs per incident', ROUND(AVG(handoffs), 2), 'handoffs', 'changes of assignment group' FROM inc;

INSERT INTO kpi_summary
SELECT 'SLA breached', ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1), '%', 'made_sla = 0 at the last event' FROM inc;

INSERT INTO kpi_summary
SELECT 'Reopened after resolution', ROUND(100.0 * AVG(reopen_count > 0), 1), '%', 'reopen_count > 0' FROM inc;

INSERT INTO kpi_summary
SELECT 'Closed without resolution time', ROUND(100.0 * AVG(resolved_at IS NULL), 1), '%', 'data completeness, rule R4' FROM inc;

INSERT INTO kpi_summary
SELECT 'Knowledge base used', ROUND(100.0 * AVG(used_knowledge), 1), '%', 'knowledge flag at the last event' FROM inc;

-- Categories that are passed on most often (priority 3, categories with 300+ incidents):
-- the first place to look when reviewing routing rules.
DROP TABLE IF EXISTS a_categories;
CREATE TABLE a_categories AS
SELECT category,
       COUNT(*)                                        AS incidents,
       ROUND(100.0 * AVG(handoffs > 0), 1)             AS handed_on_pct,
       ROUND(AVG(handoffs), 2)                         AS avg_handoffs,
       ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1) AS sla_breach_pct
FROM p3
GROUP BY category HAVING COUNT(*) >= 300
ORDER BY handed_on_pct DESC;
