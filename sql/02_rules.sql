-- 03. ITIL process and data rules, each as one SQL check.
-- Every rule returns: how many cases were checked and how many break it.
-- made_sla = 1 means the SLA was still met (the flag only ever changes 1 -> 0,
-- see R9), so a breach is made_sla = 0.

DROP TABLE IF EXISTS state_steps;
CREATE TABLE state_steps AS
SELECT number, seq, incident_state AS state,
       LAG(incident_state) OVER (PARTITION BY number ORDER BY seq) AS prev_state,
       made_sla,
       LAG(made_sla)       OVER (PARTITION BY number ORDER BY seq) AS prev_sla
FROM ev;

DROP TABLE IF EXISTS rule_results;
CREATE TABLE rule_results (rule_id TEXT, rule TEXT, level TEXT, checked INTEGER, violations INTEGER, note TEXT);

-- R1. Priority is derived from impact x urgency (ITIL priority matrix).
-- Matrix as configured in this instance: 1/1 -> 1 Critical; 1/2, 2/1 -> 2 High;
-- 2/2, 3/1 -> 3 Moderate; 2/3, 3/2, 3/3 -> 4 Low.
INSERT INTO rule_results
SELECT 'R1', 'Priority matches the impact x urgency matrix', 'event', COUNT(*),
       SUM(priority <> CASE
           WHEN impact = 1 AND urgency = 1 THEN 1
           WHEN (impact = 1 AND urgency = 2) OR (impact = 2 AND urgency = 1) THEN 2
           WHEN (impact = 2 AND urgency = 2) OR (impact = 3 AND urgency = 1) OR (impact = 1 AND urgency = 3) THEN 3
           ELSE 4 END),
       'the system computes priority itself, so 0 is expected'
FROM ev;

INSERT INTO rule_results
SELECT 'R2', 'Priority stays the same during the incident', 'incident', COUNT(*),
       SUM(n_prio > 1), 'reprioritisation is allowed in ITIL, but should be rare and explained'
FROM (SELECT number, COUNT(DISTINCT priority) AS n_prio FROM ev GROUP BY number);

INSERT INTO rule_results
SELECT 'R3', 'Lifecycle order: opened <= resolved <= closed', 'incident', COUNT(*),
       SUM(resolved_at < opened_at OR closed_at < resolved_at OR closed_at < opened_at), NULL
FROM inc;

INSERT INTO rule_results
SELECT 'R4', 'A closed incident has a resolution time', 'incident', COUNT(*),
       SUM(resolved_at IS NULL), 'closed without being resolved'
FROM inc WHERE final_state = 'Closed';

INSERT INTO rule_results
SELECT 'R5', 'A closed incident has a closure code', 'incident', COUNT(*),
       SUM(closed_code IS NULL), NULL
FROM inc WHERE final_state = 'Closed';

INSERT INTO rule_results
SELECT 'R6', 'A closed incident names who resolved it', 'incident', COUNT(*),
       SUM(resolved_by IS NULL), NULL
FROM ev WHERE seq = n_events AND incident_state = 'Closed';

INSERT INTO rule_results
SELECT 'R7', 'Closed is a final state (no activity after Closed)', 'incident',
       (SELECT COUNT(*) FROM inc),
       COUNT(DISTINCT number), 'incident reopened from Closed instead of a new ticket'
FROM state_steps WHERE prev_state = 'Closed' AND state <> 'Closed';

INSERT INTO rule_results
SELECT 'R8', 'An incident is resolved before it is closed', 'transition',
       (SELECT COUNT(*) FROM state_steps WHERE state = 'Closed' AND prev_state <> 'Closed'),
       COUNT(*), 'closed straight from New, Active or Awaiting'
FROM state_steps
WHERE state = 'Closed' AND prev_state NOT IN ('Closed', 'Resolved');

INSERT INTO rule_results
SELECT 'R9', 'An SLA breach is never undone (made_sla does not go 0 -> 1)', 'transition',
       (SELECT COUNT(*) FROM state_steps WHERE prev_sla IS NOT NULL AND prev_sla <> made_sla),
       SUM(prev_sla = 0 AND made_sla = 1), 'also proves that made_sla = 1 means "SLA met"'
FROM state_steps;

INSERT INTO rule_results
SELECT 'R10', 'A resolution holds (no Resolved -> Active)', 'incident', (SELECT COUNT(*) FROM inc),
       COUNT(DISTINCT number), 'reopened after the user rejected the fix'
FROM state_steps WHERE prev_state = 'Resolved' AND state = 'Active';

INSERT INTO rule_results
SELECT 'R11', 'Closed within 7 days after resolution', 'incident', COUNT(*),
       SUM(hours_resolved_to_closed > 168), 'most incidents auto-close 5 to 7 days after resolution'
FROM inc WHERE resolved_at IS NOT NULL;
