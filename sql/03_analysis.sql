-- 04. Analysis: does passing an incident between groups cost time and SLA?
-- Main comparisons use priority 3 (Moderate) only: 94% of incidents, and it
-- removes the effect of priority itself. Medians, not averages: resolution
-- times are heavily skewed by a few very long incidents.

-- Median hours per group of rows, done with window functions (SQLite has no MEDIAN).
DROP VIEW IF EXISTS p3;
CREATE VIEW p3 AS
SELECT *, CASE WHEN handoffs >= 4 THEN '4+' ELSE CAST(handoffs AS TEXT) END AS handoff_band
FROM inc WHERE priority = 3 AND hours_to_resolve IS NOT NULL;

DROP TABLE IF EXISTS a_handoffs;
CREATE TABLE a_handoffs AS
WITH r AS (
    SELECT handoff_band, hours_to_resolve,
           ROW_NUMBER() OVER (PARTITION BY handoff_band ORDER BY hours_to_resolve) AS rn,
           COUNT(*)     OVER (PARTITION BY handoff_band)                           AS n
    FROM p3
)
SELECT handoff_band,
       MAX(n)                                                         AS incidents,
       ROUND(AVG(CASE WHEN rn IN ((n + 1) / 2, (n + 2) / 2) THEN hours_to_resolve END), 1) AS median_hours,
       (SELECT ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1) FROM p3 x WHERE x.handoff_band = r.handoff_band) AS sla_breach_pct
FROM r GROUP BY handoff_band ORDER BY handoff_band;

DROP TABLE IF EXISTS a_pingpong;
-- Compare paths with the SAME number of handoffs (2 or 3): A -> B -> A against A -> B -> C.
-- Without this, ping-pong looks worse only because bounced incidents have more handoffs.
CREATE TABLE a_pingpong AS
WITH r AS (
    SELECT handoffs, ping_pong, hours_to_resolve, made_sla,
           ROW_NUMBER() OVER (PARTITION BY handoffs, ping_pong ORDER BY hours_to_resolve) AS rn,
           COUNT(*)     OVER (PARTITION BY handoffs, ping_pong)                           AS n
    FROM p3 WHERE handoffs IN (2, 3)
)
SELECT handoffs,
       CASE ping_pong WHEN 1 THEN 'returned to an earlier group' ELSE 'moved forward only' END AS path,
       MAX(n) AS incidents,
       ROUND(AVG(CASE WHEN rn IN ((n + 1) / 2, (n + 2) / 2) THEN hours_to_resolve END), 1) AS median_hours,
       ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1) AS sla_breach_pct
FROM r GROUP BY handoffs, ping_pong ORDER BY handoffs, ping_pong;

-- Which first-line groups send incidents on most often (groups with 200+ incidents).
DROP TABLE IF EXISTS a_groups;
CREATE TABLE a_groups AS
SELECT first_group,
       COUNT(*)                                               AS incidents,
       ROUND(100.0 * AVG(handoffs > 0), 1)                    AS handed_on_pct,
       ROUND(100.0 * AVG(ping_pong), 1)                       AS ping_pong_pct,
       ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1)        AS sla_breach_pct
FROM p3 WHERE first_group IS NOT NULL
GROUP BY first_group HAVING COUNT(*) >= 200
ORDER BY handed_on_pct DESC;

-- The overall picture by priority.
DROP TABLE IF EXISTS a_priority;
CREATE TABLE a_priority AS
SELECT priority, COUNT(*) AS incidents,
       ROUND(100.0 * SUM(made_sla = 0) / COUNT(*), 1) AS sla_breach_pct,
       ROUND(100.0 * AVG(handoffs > 0), 1)            AS handed_on_pct,
       ROUND(100.0 * AVG(ping_pong), 1)               AS ping_pong_pct
FROM inc GROUP BY priority ORDER BY priority;

-- How the log's own reassignment_count compares with group changes seen in the audit trail.
DROP TABLE IF EXISTS a_reassign_check;
CREATE TABLE a_reassign_check AS
SELECT reassignment_count - handoffs AS difference, COUNT(*) AS incidents
FROM inc GROUP BY 1 ORDER BY 1;
