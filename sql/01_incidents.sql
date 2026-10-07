-- 01. One row per incident, built from the event log.
-- Fields such as closed_at, priority or made_sla are repeated on every event
-- (they come from the database, not the audit trail), so the incident takes
-- its values from the LAST event in the log.

DROP TABLE IF EXISTS ev;
CREATE TABLE ev AS
SELECT e.*,
       ROW_NUMBER() OVER (PARTITION BY number ORDER BY sys_mod_count, sys_updated_at, rowid) AS seq,
       COUNT(*)     OVER (PARTITION BY number)                                               AS n_events
FROM events e;

DROP TABLE IF EXISTS incidents;
CREATE TABLE incidents AS
SELECT number,
       incident_state                                   AS final_state,
       priority, impact, urgency, category, contact_type,
       knowledge                                        AS used_knowledge,
       made_sla,
       reassignment_count, reopen_count, n_events,
       closed_code, assignment_group                    AS last_group,
       opened_at, resolved_at, closed_at,
       ROUND((julianday(resolved_at) - julianday(opened_at)) * 24, 1) AS hours_to_resolve,
       ROUND((julianday(closed_at)   - julianday(resolved_at)) * 24, 1) AS hours_resolved_to_closed
FROM ev
WHERE seq = n_events;

-- 02. The path of each incident through support groups.
-- Consecutive events in the same group count once; a "handoff" is a change of
-- group; a "bounce" (ping-pong) is a handoff back to a group the incident had
-- already visited.

DROP TABLE IF EXISTS group_steps;
CREATE TABLE group_steps AS
WITH g AS (
    SELECT number, seq, assignment_group AS grp,
           LAG(assignment_group) OVER (PARTITION BY number ORDER BY seq) AS prev_grp
    FROM ev
    WHERE assignment_group IS NOT NULL
)
SELECT number, seq, grp,
       ROW_NUMBER() OVER (PARTITION BY number ORDER BY seq) AS step
FROM g
WHERE prev_grp IS NULL OR grp <> prev_grp;

DROP INDEX IF EXISTS ix_steps;
CREATE INDEX IF NOT EXISTS ix_steps ON group_steps(number, grp, step);

DROP TABLE IF EXISTS group_path;
CREATE TABLE group_path AS
SELECT s.number,
       COUNT(*)            AS steps,
       COUNT(*) - 1        AS handoffs,
       COUNT(DISTINCT grp) AS groups_visited,
       SUM(CASE WHEN EXISTS (SELECT 1 FROM group_steps p
                             WHERE p.number = s.number AND p.grp = s.grp AND p.step < s.step)
                THEN 1 ELSE 0 END) AS bounces,
       MIN(CASE WHEN step = 1 THEN grp END) AS first_group
FROM group_steps s
GROUP BY s.number;

-- Final analysis table: incidents plus their group path.
-- 373 incidents never have an assignment group in the log. They are kept, but
-- their path fields stay NULL: with no group recorded there is no "first group",
-- so they must not be counted as solved without a handoff.
DROP TABLE IF EXISTS inc;
CREATE TABLE inc AS
SELECT i.*,
       p.handoffs,
       p.groups_visited,
       p.bounces,
       p.first_group,
       CASE WHEN p.number IS NULL THEN NULL WHEN p.bounces > 0 THEN 1 ELSE 0 END AS ping_pong
FROM incidents i
LEFT JOIN group_path p USING (number);
