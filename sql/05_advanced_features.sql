SELECT
    PATIENT AS patient_id,
    COUNT(DISTINCT DESCRIPTION) AS condition_burden_count
FROM 'conditions.csv'
GROUP BY PATIENT
ORDER BY condition_burden_count DESC
LIMIT 20;

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter,
        COALESCE(cb.condition_burden_count, 0) AS condition_burden_count
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
    LEFT JOIN condition_burden cb
        ON e.patient_id = cb.patient_id
)
SELECT *
FROM ed_with_patients
LIMIT 20;

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter,
        COALESCE(cb.condition_burden_count, 0) AS condition_burden_count
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
    LEFT JOIN condition_burden cb
        ON e.patient_id = cb.patient_id
)
SELECT
    *,
    CASE
        WHEN condition_burden_count = 0 THEN '0'
        WHEN condition_burden_count BETWEEN 1 AND 2 THEN '1-2'
        WHEN condition_burden_count BETWEEN 3 AND 5 THEN '3-5'
        ELSE '6+'
    END AS condition_burden_group
FROM ed_with_patients
LIMIT 20;

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
)
SELECT
    *,
    ROW_NUMBER() OVER (
        PARTITION BY patient_id
        ORDER BY encounter_start
    ) AS ed_visit_number,
    COUNT(*) OVER (
        PARTITION BY patient_id
    ) AS total_ed_visits_for_patient
FROM ed_cohort
LIMIT 20;

SELECT
    Id AS encounter_id,
    PATIENT AS patient_id,
    ENCOUNTERCLASS,
    START AS encounter_start,
    STOP AS encounter_stop,
    ROW_NUMBER() OVER (
        PARTITION BY PATIENT
        ORDER BY START
    ) AS encounter_sequence,
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
LIMIT 20;

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
        ROW_NUMBER() OVER (
            PARTITION BY PATIENT
            ORDER BY START
        ) AS encounter_sequence,
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
),
ed_final AS (
    SELECT
        u.*,
        s.next_encounter_id,
        s.next_encounter_class,
        s.next_encounter_start,
        CASE
            WHEN s.next_encounter_class = 'inpatient'
             AND s.next_encounter_start IS NOT NULL
             AND datediff('minute', u.encounter_stop, s.next_encounter_start) BETWEEN 0 AND 1440
            THEN 1
            ELSE 0
        END AS admission_after_ed_flag,
        CASE
            WHEN s.next_encounter_class = 'inpatient'
             AND s.next_encounter_start IS NOT NULL
             AND datediff('minute', u.encounter_stop, s.next_encounter_start) BETWEEN 0 AND 1440
            THEN datediff('minute', u.encounter_stop, s.next_encounter_start)
            ELSE NULL
        END AS admission_delay_proxy_minutes
    FROM ed_with_utilization u
    LEFT JOIN all_encounters_sequence s
        ON u.encounter_id = s.encounter_id
)
SELECT *
FROM ed_final
LIMIT 20;

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
        COALESCE(cb.condition_burden_count, 0) AS condition_burden_count
    FROM ed_cohort e
    LEFT JOIN condition_burden cb
        ON e.patient_id = cb.patient_id
),
ed_with_utilization AS (
    SELECT
        f.*,
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
),
ed_final AS (
    SELECT
        u.*,
        CASE
            WHEN s.next_encounter_class = 'inpatient'
             AND s.next_encounter_start IS NOT NULL
             AND datediff('minute', u.encounter_stop, s.next_encounter_start) BETWEEN 0 AND 1440
            THEN 1
            ELSE 0
        END AS admission_after_ed_flag,
        CASE
            WHEN s.next_encounter_class = 'inpatient'
             AND s.next_encounter_start IS NOT NULL
             AND datediff('minute', u.encounter_stop, s.next_encounter_start) BETWEEN 0 AND 1440
            THEN datediff('minute', u.encounter_stop, s.next_encounter_start)
            ELSE NULL
        END AS admission_delay_proxy_minutes
    FROM ed_with_utilization u
    LEFT JOIN all_encounters_sequence s
        ON u.encounter_id = s.encounter_id
)
SELECT
    COUNT(*) AS total_ed_visits,
    SUM(long_stay_flag) AS long_stay_visits,
    ROUND(100.0 * SUM(long_stay_flag) / COUNT(*), 2) AS pct_long_stay,
    SUM(repeat_ed_user_flag) AS repeat_ed_visit_rows,
    SUM(admission_after_ed_flag) AS visits_followed_by_inpatient_admission,
    AVG(admission_delay_proxy_minutes) AS avg_admission_delay_proxy_minutes
FROM ed_final;