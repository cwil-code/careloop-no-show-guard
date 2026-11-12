-- =====================================================================
-- CareLoop Clinics — No-Show Guard
-- Part 2 · SQL: verify the numbers and find where no-shows cluster
-- Engine: MySQL 8 (MySQL Workbench). In SQLiteOnline, skip the
-- CREATE DATABASE / USE lines; everything else runs unchanged.
-- =====================================================================


-- ---------------------------------------------------------------------
-- Task 2.1 — Build and load the database
-- ---------------------------------------------------------------------
CREATE DATABASE noshowguard;
USE noshowguard;

CREATE TABLE clinics (
  clinic_id VARCHAR(5) PRIMARY KEY, clinic_name VARCHAR(40) NOT NULL, city VARCHAR(20) NOT NULL,
  tier VARCHAR(10), latitude DECIMAL(8,4), longitude DECIMAL(8,4), temp_c DECIMAL(5,1));

CREATE TABLE appointments (
  appointment_id VARCHAR(8) PRIMARY KEY, patient_id VARCHAR(8) NOT NULL, clinic_id VARCHAR(5) NOT NULL,
  booked_on DATE, appt_date DATE, age INT, gender VARCHAR(1), distance_km DECIMAL(5,1), fee_inr INT,
  booking_channel VARCHAR(10), visit_type VARCHAR(12), reminder_sent VARCHAR(3), prior_no_shows INT,
  status VARCHAR(10), lead_days INT, no_show INT,
  FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id));

-- Now run load_data.sql (File > Open SQL Script > Execute).
-- It inserts the 8 clinics first, then the 990 appointments.

-- Row checks: expect 8 clinics, 990 appointments, 218 no-shows
SELECT COUNT(*) AS clinics FROM clinics;
SELECT COUNT(*) AS appointments, SUM(no_show) AS no_shows FROM appointments;

-- Primary-key test: a second row with appointment_id 'A0001' must be rejected
INSERT INTO appointments VALUES
  ('A0001','P509','C05','2025-01-24','2025-01-25',60,'F',18.0,850,'Phone','Consultation','Yes',1,'No-Show',1,1);
-- Error recorded:
--   MySQL 8 : Error Code: 1062. Duplicate entry 'A0001' for key 'appointments.PRIMARY'
--   SQLite  : UNIQUE constraint failed: appointments.appointment_id
-- The table still holds 990 rows afterwards: the primary key blocks duplicates.


-- ---------------------------------------------------------------------
-- Task 2.2 — No-show rate by clinic (clinics with >= 95 appointments)
-- ---------------------------------------------------------------------
SELECT c.clinic_name,
       c.city,
       COUNT(*)                                   AS appointments,
       SUM(a.no_show)                             AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON c.clinic_id = a.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
HAVING COUNT(*) >= 95
ORDER BY no_show_pct DESC;

-- Same query without HAVING: all 8 clinics.
SELECT c.clinic_name,
       c.city,
       COUNT(*)                                   AS appointments,
       SUM(a.no_show)                             AS no_shows,
       ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
FROM appointments a
JOIN clinics c ON c.clinic_id = a.clinic_id
GROUP BY c.clinic_id, c.clinic_name, c.city
ORDER BY no_show_pct DESC;
-- Observation: Gomti Nagar Care Point (Lucknow) has the highest rate, 33.3%,
-- but on only 90 appointments, so the HAVING filter (>= 95) excludes it.
-- Sitabuldi Health Point (Nagpur) is the other excluded clinic: 82 appointments, 15.9%.
-- The pandas groupby check in 03_model.ipynb (Section 0) reproduces these counts exactly.


-- ---------------------------------------------------------------------
-- Task 2.3 — Does booking far ahead matter? (lead-time bands)
-- ---------------------------------------------------------------------
SELECT CASE
         WHEN lead_days <= 7  THEN '1-7'
         WHEN lead_days <= 14 THEN '8-14'
         WHEN lead_days <= 30 THEN '15-30'
         ELSE '31+'
       END                                        AS lead_band,
       COUNT(*)                                   AS appointments,
       SUM(no_show)                               AS no_shows,
       ROUND(100.0 * SUM(no_show) / COUNT(*), 1)  AS no_show_pct
FROM appointments
GROUP BY lead_band
ORDER BY MIN(lead_days);


-- ---------------------------------------------------------------------
-- Task 2.4 — Month-by-month trend with LAG()
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT SUBSTR(appt_date, 1, 7)                    AS month,
         COUNT(*)                                   AS appointments,
         ROUND(100.0 * SUM(no_show) / COUNT(*), 1)  AS no_show_pct
  FROM appointments
  GROUP BY SUBSTR(appt_date, 1, 7)
)
SELECT month,
       appointments,
       no_show_pct,
       ROUND(no_show_pct - LAG(no_show_pct) OVER (ORDER BY month), 1) AS change_pp
FROM monthly
ORDER BY month;


-- ---------------------------------------------------------------------
-- Task 2.5 — Rank clinics inside each city vs the overall rate
-- ---------------------------------------------------------------------
WITH clinic_rates AS (
  SELECT c.clinic_name                               AS clinic,
         c.city,
         ROUND(100.0 * SUM(a.no_show) / COUNT(*), 1) AS no_show_pct
  FROM appointments a
  JOIN clinics c ON c.clinic_id = a.clinic_id
  GROUP BY c.clinic_id, c.clinic_name, c.city
)
SELECT clinic,
       city,
       no_show_pct,
       RANK() OVER (PARTITION BY city ORDER BY no_show_pct DESC) AS rank_in_city,
       CASE
         WHEN no_show_pct > (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'above'
         WHEN no_show_pct < (SELECT 100.0 * SUM(no_show) / COUNT(*) FROM appointments) THEN 'below'
         ELSE 'equal'
       END AS vs_overall
FROM clinic_rates
ORDER BY city, rank_in_city;
-- Overall rate = 218 / 990 = 22.02%.
