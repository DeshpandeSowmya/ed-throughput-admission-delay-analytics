Step 1: Joining the ED cohort to patients

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
    e.*,
    p.BIRTHDATE,
    p.RACE,
    p.ETHNICITY,
    p.GENDER,
    p.COUNTY
FROM ed_cohort e
LEFT JOIN 'patients.csv' p
    ON e.patient_id = p.Id
LIMIT 20;

Step 2: Calculating age at encounter

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
    e.*,
    p.BIRTHDATE,
    p.RACE,
    p.ETHNICITY,
    p.GENDER,
    p.COUNTY,
    datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter
FROM ed_cohort e
LEFT JOIN 'patients.csv' p
    ON e.patient_id = p.Id
LIMIT 20;

Step 3: Creating age groups

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
)
SELECT
    *,
    CASE
        WHEN age_at_encounter < 18 THEN '0-17'
        WHEN age_at_encounter BETWEEN 18 AND 34 THEN '18-34'
        WHEN age_at_encounter BETWEEN 35 AND 49 THEN '35-49'
        WHEN age_at_encounter BETWEEN 50 AND 64 THEN '50-64'
        WHEN age_at_encounter >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_group
FROM ed_with_patients
LIMIT 20;

Step 4: Deriving arrival hour, weekday, month, and shift

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
)
SELECT
    *,
    CASE
        WHEN age_at_encounter < 18 THEN '0-17'
        WHEN age_at_encounter BETWEEN 18 AND 34 THEN '18-34'
        WHEN age_at_encounter BETWEEN 35 AND 49 THEN '35-49'
        WHEN age_at_encounter BETWEEN 50 AND 64 THEN '50-64'
        WHEN age_at_encounter >= 65 THEN '65+'
        ELSE 'Unknown'
    END AS age_group,
    EXTRACT(hour FROM encounter_start) AS arrival_hour,
    dayname(encounter_start) AS arrival_weekday,
    monthname(encounter_start) AS arrival_month,
    CASE
        WHEN EXTRACT(hour FROM encounter_start) BETWEEN 7 AND 14 THEN 'Day'
        WHEN EXTRACT(hour FROM encounter_start) BETWEEN 15 AND 22 THEN 'Evening'
        ELSE 'Night'
    END AS arrival_shift
FROM ed_with_patients
LIMIT 20;

Step 5: Joining payer details

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
),
ed_with_time AS (
    SELECT
        *,
        CASE
            WHEN age_at_encounter < 18 THEN '0-17'
            WHEN age_at_encounter BETWEEN 18 AND 34 THEN '18-34'
            WHEN age_at_encounter BETWEEN 35 AND 49 THEN '35-49'
            WHEN age_at_encounter BETWEEN 50 AND 64 THEN '50-64'
            WHEN age_at_encounter >= 65 THEN '65+'
            ELSE 'Unknown'
        END AS age_group,
        EXTRACT(hour FROM encounter_start) AS arrival_hour,
        dayname(encounter_start) AS arrival_weekday,
        monthname(encounter_start) AS arrival_month,
        CASE
            WHEN EXTRACT(hour FROM encounter_start) BETWEEN 7 AND 14 THEN 'Day'
            WHEN EXTRACT(hour FROM encounter_start) BETWEEN 15 AND 22 THEN 'Evening'
            ELSE 'Night'
        END AS arrival_shift
    FROM ed_with_patients
)
SELECT
    t.*,
    py.NAME AS payer_name
FROM ed_with_time t
LEFT JOIN 'payers.csv' py
    ON t.payer_id = py.Id
LIMIT 20;

Step 6: Creating the long-stay flag

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
ed_with_patients AS (
    SELECT
        e.*,
        p.BIRTHDATE,
        p.RACE,
        p.ETHNICITY,
        p.GENDER,
        p.COUNTY,
        datediff('year', p.BIRTHDATE, e.encounter_start) AS age_at_encounter
    FROM ed_cohort e
    LEFT JOIN 'patients.csv' p
        ON e.patient_id = p.Id
),
ed_with_time AS (
    SELECT
        *,
        CASE
            WHEN age_at_encounter < 18 THEN '0-17'
            WHEN age_at_encounter BETWEEN 18 AND 34 THEN '18-34'
            WHEN age_at_encounter BETWEEN 35 AND 49 THEN '35-49'
            WHEN age_at_encounter BETWEEN 50 AND 64 THEN '50-64'
            WHEN age_at_encounter >= 65 THEN '65+'
            ELSE 'Unknown'
        END AS age_group,
        EXTRACT(hour FROM encounter_start) AS arrival_hour,
        dayname(encounter_start) AS arrival_weekday,
        monthname(encounter_start) AS arrival_month,
        CASE
            WHEN EXTRACT(hour FROM encounter_start) BETWEEN 7 AND 14 THEN 'Day'
            WHEN EXTRACT(hour FROM encounter_start) BETWEEN 15 AND 22 THEN 'Evening'
            ELSE 'Night'
        END AS arrival_shift
    FROM ed_with_patients
),
ed_enriched AS (
    SELECT
        t.*,
        py.NAME AS payer_name,
        CASE
            WHEN t.ed_los_minutes > 240 THEN 1
            ELSE 0
        END AS long_stay_flag
    FROM ed_with_time t
    LEFT JOIN 'payers.csv' py
        ON t.payer_id = py.Id
)
SELECT *
FROM ed_enriched
LIMIT 20;