CREATE OR REPLACE TEMP VIEW ed_final AS
WITH ed_cohort AS (
    SELECT
        Id AS encounter_id,
        PATIENT AS patient_id,
        ORGANIZATION AS organization_id,
        PROVIDER AS provider_id,
        PAYER AS payer_id,
        START AS encounter_start,
        STOP AS encounter_stop,
        DESCRIPTION,
        REASONCODE,
        REASONDESCRIPTION,
        TOTAL_CLAIM_COST,
        PAYER_COVERAGE,
        datediff('minute', START, STOP) AS ed_los_minutes
    FROM 'encounters.csv'
    WHERE ENCOUNTERCLASS = 'emergency'
      AND START IS NOT NULL
      AND STOP IS NOT NULL
      AND datediff('minute', START, STOP) >= 0
),
condition_burden AS (
    SELECT
        PATIENT AS patient_id,
        COUNT(DISTINCT DESCRIPTION) AS condition_burden_count
    FROM 'conditions.csv'
    GROUP BY PATIENT
),
all_encounters_sequence AS (
    SELECT
        Id AS encounter_id,
        PATIENT AS patient_id,
        ENCOUNTERCLASS,
        START AS encounter_start,
        STOP AS encounter_stop,
        LEAD(Id) OVER (
            PARTITION BY PATIENT
            ORDER BY START
        ) AS next_encounter_id,
        LEAD(ENCOUNTERCLASS) OVER (
            PARTITION BY PATIENT
            ORDER BY START
        ) AS next_encounter_class,
        LEAD(START) OVER (
            PARTITION BY PATIENT
            ORDER BY START
        ) AS next_encounter_start
    FROM 'encounters.csv'
    WHERE START IS NOT NULL
),
ed_with_features AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter,
        CASE
            WHEN datediff('year', p.BIRTHDATE, e.encounter_start) < 18 THEN '0-17'
            WHEN datediff('year', p.BIRTHDATE, e.encounter_start) BETWEEN 18 AND 34 THEN '18-34'
            WHEN datediff('year', p.BIRTHDATE, e.encounter_start) BETWEEN 35 AND 49 THEN '35-49'
            WHEN datediff('year', p.BIRTHDATE, e.encounter_start) BETWEEN 50 AND 64 THEN '50-64'
            WHEN datediff('year', p.BIRTHDATE, e.encounter_start) >= 65 THEN '65+'
            ELSE 'Unknown'
        END AS age_group,
        EXTRACT(hour FROM e.encounter_start) AS arrival_hour,
        dayname(e.encounter_start) AS arrival_weekday,
        monthname(e.encounter_start) AS arrival_month,
        date_trunc('month', e.encounter_start) AS arrival_month_date,
        CASE
            WHEN EXTRACT(hour FROM e.encounter_start) BETWEEN 7 AND 14 THEN 'Day'
            WHEN EXTRACT(hour FROM e.encounter_start) BETWEEN 15 AND 22 THEN 'Evening'
            ELSE 'Night'
        END AS arrival_shift,
        COALESCE(cb.condition_burden_count, 0) AS condition_burden_count,
        CASE
            WHEN COALESCE(cb.condition_burden_count, 0) = 0 THEN '0'
            WHEN COALESCE(cb.condition_burden_count, 0) BETWEEN 1 AND 2 THEN '1-2'
            WHEN COALESCE(cb.condition_burden_count, 0) BETWEEN 3 AND 5 THEN '3-5'
            ELSE '6+'
        END AS condition_burden_group,
        COALESCE(py.NAME, 'Unknown') AS payer_name
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
    LEFT JOIN condition_burden cb
        ON e.patient_id = cb.patient_id
    LEFT JOIN 'payers.csv' py
        ON e.payer_id = py.Id
),
ed_with_utilization AS (
    SELECT
        f.*,
        ROW_NUMBER() OVER (
            PARTITION BY f.patient_id
            ORDER BY f.encounter_start
        ) AS ed_visit_number,
        COUNT(*) OVER (
            PARTITION BY f.patient_id
        ) AS total_ed_visits_for_patient,
        CASE
            WHEN COUNT(*) OVER (PARTITION BY f.patient_id) > 1 THEN 1
            ELSE 0
        END AS repeat_ed_user_flag,
        CASE
            WHEN f.ed_los_minutes > 240 THEN 1
            ELSE 0
        END AS long_stay_flag
    FROM ed_with_features f
)
SELECT
    u.*,
    s.next_encounter_id,
    s.next_encounter_class,
    s.next_encounter_start,
    CASE
        WHEN s.next_encounter_class = 'inpatient' THEN 1
        ELSE 0
    END AS next_encounter_inpatient_flag
FROM ed_with_utilization u
LEFT JOIN all_encounters_sequence s
    ON u.encounter_id = s.encounter_id;

SELECT *
FROM ed_final;

SELECT
    COUNT(*) AS total_ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    MEDIAN(ed_los_minutes) AS median_ed_los_minutes,
    SUM(long_stay_flag) AS long_stay_visits,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay,
    SUM(repeat_ed_user_flag) AS repeat_ed_visit_rows,
    ROUND(100.0 * SUM(repeat_ed_user_flag) / COUNT(*), 2) AS pct_repeat_ed_user,
    SUM(next_encounter_inpatient_flag) AS next_encounter_inpatient_visits,
    ROUND(100.0 * SUM(next_encounter_inpatient_flag) / COUNT(*), 2) AS pct_next_encounter_inpatient
FROM ed_final;

SELECT
    payer_name,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    MEDIAN(ed_los_minutes) AS median_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay,
    ROUND(100.0 * SUM(next_encounter_inpatient_flag) / COUNT(*), 2) AS pct_next_encounter_inpatient
FROM ed_final
GROUP BY payer_name
HAVING COUNT(*) >= 5
ORDER BY avg_ed_los_minutes DESC;

SELECT
    COALESCE(REASONDESCRIPTION, DESCRIPTION, 'Unknown') AS reason_group,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    MEDIAN(ed_los_minutes) AS median_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY COALESCE(REASONDESCRIPTION, DESCRIPTION, 'Unknown')
HAVING COUNT(*) >= 3
ORDER BY avg_ed_los_minutes DESC;

SELECT
    'Age Group' AS equity_dimension,
    age_group AS equity_value,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY age_group

UNION ALL

SELECT
    'Race' AS equity_dimension,
    COALESCE(RACE, 'Unknown') AS equity_value,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY COALESCE(RACE, 'Unknown')

UNION ALL

SELECT
    'Ethnicity' AS equity_dimension,
    COALESCE(ETHNICITY, 'Unknown') AS equity_value,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY COALESCE(ETHNICITY, 'Unknown')

UNION ALL

SELECT
    'Condition Burden' AS equity_dimension,
    condition_burden_group AS equity_value,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY condition_burden_group;

SELECT
    arrival_weekday,
    arrival_hour,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes
FROM ed_final
GROUP BY arrival_weekday, arrival_hour
ORDER BY arrival_weekday, arrival_hour;

SELECT
    arrival_shift,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay,
    ROUND(100.0 * SUM(next_encounter_inpatient_flag) / COUNT(*), 2) AS pct_next_encounter_inpatient
FROM ed_final
GROUP BY arrival_shift
ORDER BY avg_ed_los_minutes DESC;

SELECT
    arrival_month_date,
    COUNT(*) AS ed_visits,
    ROUND(AVG(ed_los_minutes), 2) AS avg_ed_los_minutes,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay
FROM ed_final
GROUP BY arrival_month_date
ORDER BY arrival_month_date;