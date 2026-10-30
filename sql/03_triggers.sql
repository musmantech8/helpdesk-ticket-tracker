-- =============================================================
-- Triggers: SLA due date, resolved date, and the status history log
-- =============================================================

-- Sets the due date from the priority on a new ticket, only accepts the allowed
-- status flow (whoever makes the change), and keeps RESOLVED_ON in step with the status.
CREATE OR REPLACE TRIGGER hdk_tickets_biu
  BEFORE INSERT OR UPDATE ON hdk_tickets
  FOR EACH ROW
BEGIN
  IF INSERTING THEN
    :NEW.due_on := NVL(:NEW.due_on,
                       NVL(:NEW.created_on, SYSDATE) + hdk_ticket_pkg.sla_hours(:NEW.priority) / 24);
  ELSIF :OLD.status <> :NEW.status THEN
    IF NOT hdk_ticket_pkg.is_valid_transition(:OLD.status, :NEW.status) THEN
      RAISE_APPLICATION_ERROR(-20402,
        'A ticket cannot move from ' || :OLD.status || ' to ' || :NEW.status || '.');
    END IF;
  END IF;

  IF :NEW.status IN ('RESOLVED', 'CLOSED') THEN
    :NEW.resolved_on := NVL(:NEW.resolved_on, SYSDATE);
  ELSE
    :NEW.resolved_on := NULL;   -- a re-opened ticket is no longer resolved
  END IF;
END;
/

-- Every status change (and the first status of a ticket) is written to the history.
CREATE OR REPLACE TRIGGER hdk_tickets_aiu
  AFTER INSERT OR UPDATE OF status ON hdk_tickets
  FOR EACH ROW
BEGIN
  IF INSERTING THEN
    INSERT INTO hdk_status_history (ticket_id, old_status, new_status, changed_on)
    VALUES (:NEW.ticket_id, NULL, :NEW.status, :NEW.created_on);
  ELSIF :OLD.status <> :NEW.status THEN
    INSERT INTO hdk_status_history (ticket_id, old_status, new_status)
    VALUES (:NEW.ticket_id, :OLD.status, :NEW.status);
  END IF;
END;
/
