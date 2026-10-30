# Helpdesk Ticket Tracker

An IT helpdesk application built with **Oracle APEX** and **PL/SQL**. Users raise tickets, agents work them through a controlled status flow, and every change is logged.

## Features

- **Dashboard:** open tickets, overdue tickets, unassigned tickets, resolved today, and average resolution time, with charts.
- **Tickets:** administrators see all tickets; normal users see only the tickets they raised.
- **Agents:** administrator-only management of support agents and their workload.
- **Status history:** every status change is recorded automatically.
- **Accounts:** self-service sign-up. The first account becomes the administrator.
- **SLA due dates:** set automatically from priority (urgent 4 hours, high 24 hours, medium 72 hours, low 120 hours).

## Business rules

- A ticket moves only along the allowed flow: NEW → IN_PROGRESS or ON_HOLD; IN_PROGRESS → ON_HOLD or RESOLVED; ON_HOLD → IN_PROGRESS; RESOLVED → CLOSED or re-opened to IN_PROGRESS.
- Assigning an agent moves a NEW ticket to IN_PROGRESS.
- Normal users cannot set a ticket's status, agent or dates, and their details come from their own account.
- Closed tickets cannot be changed or reassigned.

## Database

Run the scripts in `sql/` in this order:

| Script | What it creates |
| --- | --- |
| `01_schema.sql` | Tables, constraints, indexes and the sign-up table |
| `02_ticket_pkg.sql` | `HDK_TICKET_PKG`: SLA hours and status rules |
| `03_triggers.sql` | Due dates, resolved dates and the status history log |
| `04_views.sql` | Report views and dashboard numbers |
| `05_sample_data.sql` | Agents, sample tickets and comments |
| `06_auth.sql` | Accounts, `HDK_AUTH_PKG` (hashed passwords, admin check) and admin-only triggers |

Passwords are never stored in plain text. Each one is stored as a salted hash.

## Application

The APEX application uses a custom authentication scheme (`hdk_auth_pkg.authenticate`) and an *Administration Rights* authorization scheme (`hdk_auth_pkg.is_admin`). The tickets report is filtered by the same rule in the database.

### First run

1. Run the SQL scripts above in SQL Workshop.
2. Import the application into your workspace.
3. Open the sign-in page and choose **Create an account**. The first account becomes the administrator.

## Tech

Oracle APEX · Oracle Database · PL/SQL · SQL

---

Built by [Muhammad Usman](https://github.com/musmantech8), Oracle APEX Developer.
