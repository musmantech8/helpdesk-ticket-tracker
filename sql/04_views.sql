-- =============================================================
-- Report views used by the APEX pages
-- =============================================================

-- Tickets with the agent name, age, and whether the SLA has been missed.
CREATE OR REPLACE VIEW hdk_tickets_v AS
SELECT t.ticket_id,
       t.title,
       t.category,
       t.priority,
       t.status,
       t.requester_name,
       t.requester_email,
       t.agent_id,
       a.full_name AS agent_name,
       t.created_on,
       t.due_on,
       t.resolved_on,
       ROUND(NVL(t.resolved_on, SYSDATE) - t.created_on, 1) AS age_days,
       CASE WHEN t.status NOT IN ('RESOLVED', 'CLOSED') AND t.due_on < SYSDATE
            THEN 'Y' ELSE 'N' END AS is_overdue
  FROM hdk_tickets t
  LEFT JOIN hdk_agents a ON a.agent_id = t.agent_id;

-- One row of numbers for the dashboard cards.
CREATE OR REPLACE VIEW hdk_dashboard_v AS
SELECT (SELECT COUNT(*) FROM hdk_tickets WHERE status NOT IN ('RESOLVED', 'CLOSED'))        AS open_tickets,
       (SELECT COUNT(*) FROM hdk_tickets
         WHERE status NOT IN ('RESOLVED', 'CLOSED') AND due_on < SYSDATE)                   AS overdue_tickets,
       (SELECT COUNT(*) FROM hdk_tickets
         WHERE status = 'NEW' AND agent_id IS NULL)                                          AS unassigned_tickets,
       (SELECT COUNT(*) FROM hdk_tickets
         WHERE resolved_on >= TRUNC(SYSDATE))                                                AS resolved_today,
       (SELECT ROUND(AVG((resolved_on - created_on) * 24), 1)
          FROM hdk_tickets WHERE resolved_on IS NOT NULL)                                    AS avg_resolution_hours
  FROM dual;

-- Workload per agent (open tickets only).
CREATE OR REPLACE VIEW hdk_agent_load_v AS
SELECT a.agent_id,
       a.full_name,
       COUNT(t.ticket_id) AS open_tickets
  FROM hdk_agents a
  LEFT JOIN hdk_tickets t
         ON t.agent_id = a.agent_id
        AND t.status NOT IN ('RESOLVED', 'CLOSED')
 WHERE a.is_active = 'Y'
 GROUP BY a.agent_id, a.full_name;
