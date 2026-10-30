-- =============================================================
-- Sample data (fictional people, example.com emails). Safe to run twice:
-- agents use MERGE and the ticket block only runs on an empty table.
-- =============================================================

MERGE INTO hdk_agents t
USING (
  SELECT 'Noor Fatima' AS full_name, 'noor.fatima@example.com' AS email FROM dual UNION ALL
  SELECT 'Imran Shah',   'imran.shah@example.com'   FROM dual UNION ALL
  SELECT 'Mariam Javed', 'mariam.javed@example.com' FROM dual UNION ALL
  SELECT 'Talha Nadeem', 'talha.nadeem@example.com' FROM dual
) s
ON (t.email = s.email)
WHEN NOT MATCHED THEN INSERT (full_name, email) VALUES (s.full_name, s.email);

DECLARE
  l_count NUMBER;

  FUNCTION agent (p_email IN VARCHAR2) RETURN NUMBER IS
    l_id hdk_agents.agent_id%TYPE;
  BEGIN
    SELECT agent_id INTO l_id FROM hdk_agents WHERE email = p_email;
    RETURN l_id;
  END agent;

  -- Inserts a ticket created p_days_ago days back, in the given status.
  PROCEDURE ticket (
    p_title IN VARCHAR2, p_desc IN VARCHAR2, p_category IN VARCHAR2,
    p_requester IN VARCHAR2, p_priority IN VARCHAR2, p_status IN VARCHAR2,
    p_agent_email IN VARCHAR2, p_days_ago IN NUMBER, p_resolved_after_hours IN NUMBER DEFAULT NULL
  ) IS
    l_created  DATE := SYSDATE - p_days_ago;
    l_agent_id hdk_agents.agent_id%TYPE;
    l_resolved DATE;
  BEGIN
    -- A local function cannot be called inside the INSERT, so look the values up first.
    IF p_agent_email IS NOT NULL THEN
      l_agent_id := agent(p_agent_email);
    END IF;
    IF p_resolved_after_hours IS NOT NULL THEN
      l_resolved := l_created + p_resolved_after_hours / 24;
    END IF;

    INSERT INTO hdk_tickets
      (title, description, category, requester_name, requester_email, priority, status,
       agent_id, created_on, resolved_on)
    VALUES
      (p_title, p_desc, p_category, p_requester,
       LOWER(REPLACE(p_requester, ' ', '.')) || '@example.com', p_priority, p_status,
       l_agent_id, l_created, l_resolved);
  END ticket;
BEGIN
  SELECT COUNT(*) INTO l_count FROM hdk_tickets;

  IF l_count = 0 THEN
    ticket('Cannot log in to the VPN', 'VPN client rejects my password since Monday.', 'Access', 'Ali Raza', 'HIGH', 'IN_PROGRESS', 'noor.fatima@example.com', 1);
    ticket('Printer on floor 2 is offline', 'Shows offline for everyone on the second floor.', 'Hardware', 'Sana Iqbal', 'MEDIUM', 'IN_PROGRESS', 'imran.shah@example.com', 2);
    ticket('Need access to the sales dashboard', 'New joiner in the sales team needs read access.', 'Access', 'Kamran Butt', 'LOW', 'NEW', NULL, 0);
    ticket('Email not syncing on phone', 'Mailbox stopped syncing after the OS update.', 'Email', 'Rabia Aslam', 'MEDIUM', 'ON_HOLD', 'mariam.javed@example.com', 4);
    ticket('Server room temperature alert', 'Monitoring shows the temperature above the limit.', 'Infrastructure', 'Farhan Yousaf', 'URGENT', 'IN_PROGRESS', 'talha.nadeem@example.com', 1);
    ticket('Laptop battery drains in an hour', 'Battery health report shows 40 percent.', 'Hardware', 'Mehwish Khan', 'LOW', 'NEW', NULL, 3);
    ticket('Install design software', 'Need the design suite installed on my workstation.', 'Software', 'Danish Malik', 'MEDIUM', 'RESOLVED', 'imran.shah@example.com', 5, 20);
    ticket('Reset shared mailbox password', 'Shared support mailbox is locked.', 'Email', 'Lubna Hassan', 'HIGH', 'RESOLVED', 'noor.fatima@example.com', 3, 6);
    ticket('Wi-Fi drops in meeting room B', 'Connection drops every few minutes during calls.', 'Network', 'Shahid Mehmood', 'HIGH', 'CLOSED', 'talha.nadeem@example.com', 9, 30);
    ticket('Monitor flickering', 'Second monitor flickers when plugged in over HDMI.', 'Hardware', 'Areeba Noman', 'LOW', 'CLOSED', 'mariam.javed@example.com', 12, 70);
    ticket('Database report is slow', 'Month-end report takes over ten minutes to open.', 'Software', 'Waqar Hussain', 'MEDIUM', 'NEW', NULL, 5);
    ticket('Request for a second keyboard', 'Ergonomic keyboard requested after a wrist strain.', 'Hardware', 'Tooba Zafar', 'LOW', 'RESOLVED', 'imran.shah@example.com', 2, 26);

    INSERT INTO hdk_comments (ticket_id, comment_text, is_internal)
    SELECT ticket_id, 'Checked the account: it is locked after too many attempts. Unlocking and resetting.', 'N'
      FROM hdk_tickets WHERE title = 'Cannot log in to the VPN';
    INSERT INTO hdk_comments (ticket_id, comment_text, is_internal)
    SELECT ticket_id, 'Switch port looks fine, suspect the power supply of the printer.', 'Y'
      FROM hdk_tickets WHERE title = 'Printer on floor 2 is offline';
    INSERT INTO hdk_comments (ticket_id, comment_text, is_internal)
    SELECT ticket_id, 'Waiting for the vendor to confirm the replacement cooling unit.', 'N'
      FROM hdk_tickets WHERE title = 'Server room temperature alert';
    INSERT INTO hdk_comments (ticket_id, comment_text, is_internal)
    SELECT ticket_id, 'Replaced the access point firmware, no drops in 48 hours.', 'N'
      FROM hdk_tickets WHERE title = 'Wi-Fi drops in meeting room B';
  END IF;
END;
/

COMMIT;
