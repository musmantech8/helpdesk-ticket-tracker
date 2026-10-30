-- =============================================================
-- HDK_TICKET_PKG — ticket rules: SLA, assignment, status flow, comments
-- Example APEX usage (page process on the Ticket page):
--   hdk_ticket_pkg.change_status(p_ticket_id => :P3_TICKET_ID, p_new_status => :P3_STATUS);
-- Error codes: -20401 unknown ticket, -20402 invalid status change,
--              -20403 agent unavailable, -20404 ticket is closed,
--              -20405 empty comment
-- Status flow:  NEW -> IN_PROGRESS | ON_HOLD
--               IN_PROGRESS -> ON_HOLD | RESOLVED
--               ON_HOLD -> IN_PROGRESS
--               RESOLVED -> CLOSED | IN_PROGRESS (re-open)
-- =============================================================

CREATE OR REPLACE PACKAGE hdk_ticket_pkg AS

  -- Hours allowed to resolve a ticket, by priority.
  FUNCTION sla_hours (p_priority IN VARCHAR2) RETURN NUMBER DETERMINISTIC;

  FUNCTION is_valid_transition (p_from IN VARCHAR2, p_to IN VARCHAR2) RETURN BOOLEAN;

  PROCEDURE create_ticket (
    p_title           IN hdk_tickets.title%TYPE,
    p_description     IN hdk_tickets.description%TYPE,
    p_category        IN hdk_tickets.category%TYPE,
    p_requester_name  IN hdk_tickets.requester_name%TYPE,
    p_requester_email IN hdk_tickets.requester_email%TYPE,
    p_priority        IN hdk_tickets.priority%TYPE DEFAULT 'MEDIUM'
  );

  PROCEDURE assign_ticket (
    p_ticket_id IN hdk_tickets.ticket_id%TYPE,
    p_agent_id  IN hdk_agents.agent_id%TYPE
  );

  PROCEDURE change_status (
    p_ticket_id  IN hdk_tickets.ticket_id%TYPE,
    p_new_status IN hdk_tickets.status%TYPE
  );

  PROCEDURE add_comment (
    p_ticket_id    IN hdk_tickets.ticket_id%TYPE,
    p_comment_text IN hdk_comments.comment_text%TYPE,
    p_is_internal  IN hdk_comments.is_internal%TYPE DEFAULT 'N'
  );

END hdk_ticket_pkg;
/

CREATE OR REPLACE PACKAGE BODY hdk_ticket_pkg AS

  FUNCTION sla_hours (p_priority IN VARCHAR2) RETURN NUMBER DETERMINISTIC IS
  BEGIN
    RETURN CASE p_priority
             WHEN 'URGENT' THEN 4
             WHEN 'HIGH'   THEN 24
             WHEN 'MEDIUM' THEN 72
             ELSE 120
           END;
  END sla_hours;

  FUNCTION is_valid_transition (p_from IN VARCHAR2, p_to IN VARCHAR2) RETURN BOOLEAN IS
  BEGIN
    IF p_from = 'NEW' THEN
      RETURN p_to IN ('IN_PROGRESS', 'ON_HOLD');
    ELSIF p_from = 'IN_PROGRESS' THEN
      RETURN p_to IN ('ON_HOLD', 'RESOLVED');
    ELSIF p_from = 'ON_HOLD' THEN
      RETURN p_to = 'IN_PROGRESS';
    ELSIF p_from = 'RESOLVED' THEN
      RETURN p_to IN ('CLOSED', 'IN_PROGRESS');
    END IF;
    RETURN FALSE;
  END is_valid_transition;

  -- Locks the ticket row and returns its current status.
  FUNCTION lock_ticket (p_ticket_id IN hdk_tickets.ticket_id%TYPE) RETURN hdk_tickets.status%TYPE IS
    l_status hdk_tickets.status%TYPE;
  BEGIN
    SELECT status INTO l_status
      FROM hdk_tickets
     WHERE ticket_id = p_ticket_id
       FOR UPDATE;
    RETURN l_status;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20401, 'Ticket ' || p_ticket_id || ' does not exist.');
  END lock_ticket;

  PROCEDURE create_ticket (
    p_title           IN hdk_tickets.title%TYPE,
    p_description     IN hdk_tickets.description%TYPE,
    p_category        IN hdk_tickets.category%TYPE,
    p_requester_name  IN hdk_tickets.requester_name%TYPE,
    p_requester_email IN hdk_tickets.requester_email%TYPE,
    p_priority        IN hdk_tickets.priority%TYPE DEFAULT 'MEDIUM'
  ) IS
  BEGIN
    -- Triggers set the due date from the priority and log the first status.
    INSERT INTO hdk_tickets (title, description, category, requester_name, requester_email, priority)
    VALUES (TRIM(p_title), p_description, NVL(p_category, 'General'), TRIM(p_requester_name),
            LOWER(TRIM(p_requester_email)), NVL(p_priority, 'MEDIUM'));
  END create_ticket;

  PROCEDURE assign_ticket (
    p_ticket_id IN hdk_tickets.ticket_id%TYPE,
    p_agent_id  IN hdk_agents.agent_id%TYPE
  ) IS
    l_status hdk_tickets.status%TYPE;
    l_active hdk_agents.is_active%TYPE;
  BEGIN
    l_status := lock_ticket(p_ticket_id);

    IF l_status = 'CLOSED' THEN
      RAISE_APPLICATION_ERROR(-20404, 'A closed ticket cannot be reassigned.');
    END IF;

    BEGIN
      SELECT is_active INTO l_active FROM hdk_agents WHERE agent_id = p_agent_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20403, 'Agent ' || p_agent_id || ' does not exist.');
    END;

    IF l_active <> 'Y' THEN
      RAISE_APPLICATION_ERROR(-20403, 'This agent is not active.');
    END IF;

    UPDATE hdk_tickets
       SET agent_id = p_agent_id,
           status   = CASE WHEN status = 'NEW' THEN 'IN_PROGRESS' ELSE status END
     WHERE ticket_id = p_ticket_id;
  END assign_ticket;

  PROCEDURE change_status (
    p_ticket_id  IN hdk_tickets.ticket_id%TYPE,
    p_new_status IN hdk_tickets.status%TYPE
  ) IS
    l_status hdk_tickets.status%TYPE;
  BEGIN
    l_status := lock_ticket(p_ticket_id);

    IF l_status = 'CLOSED' THEN
      RAISE_APPLICATION_ERROR(-20404, 'A closed ticket cannot be changed.');
    END IF;

    IF NOT is_valid_transition(l_status, p_new_status) THEN
      RAISE_APPLICATION_ERROR(-20402,
        'A ticket cannot move from ' || l_status || ' to ' || p_new_status || '.');
    END IF;

    UPDATE hdk_tickets
       SET status = p_new_status
     WHERE ticket_id = p_ticket_id;
  END change_status;

  PROCEDURE add_comment (
    p_ticket_id    IN hdk_tickets.ticket_id%TYPE,
    p_comment_text IN hdk_comments.comment_text%TYPE,
    p_is_internal  IN hdk_comments.is_internal%TYPE DEFAULT 'N'
  ) IS
    l_status hdk_tickets.status%TYPE;
  BEGIN
    IF p_comment_text IS NULL OR TRIM(p_comment_text) IS NULL THEN
      RAISE_APPLICATION_ERROR(-20405, 'Please write a comment first.');
    END IF;

    l_status := lock_ticket(p_ticket_id);

    INSERT INTO hdk_comments (ticket_id, comment_text, is_internal)
    VALUES (p_ticket_id, TRIM(p_comment_text), NVL(p_is_internal, 'N'));
  END add_comment;

END hdk_ticket_pkg;
/
