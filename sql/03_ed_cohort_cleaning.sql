SELECT COUNT(*) AS emergency_visit_count
FROM 'encounters.csv'
WHERE ENCOUNTERCLASS = 'emergency';

SELECT *
FROM 'encounters.csv'
WHERE ENCOUNTERCLASS = 'emergency'
LIMIT 10;

SELECT
    COUNT(*) AS total_emergency_rows,
    SUM(CASE WHEN START IS NULL THEN 1 ELSE 0 END) AS missing_start,
    SUM(CASE WHEN STOP IS NULL THEN 1 ELSE 0 END) AS missing_stop
FROM 'encounters.csv'
WHERE ENCOUNTERCLASS = 'emergency';

SELECT
    Id,
    PATIENT,
    START,
    STOP,
    datediff('minute', START, STOP) AS ed_los_minutes
FROM 'encounters.csv'
WHERE ENCOUNTERCLASS = 'emergency'
LIMIT 20;

SELECT
    COUNT(*) AS total_emergency_rows,
    SUM(CASE WHEN datediff('minute', START, STOP) < 0 THEN 1 ELSE 0 END) AS negative_los_rows,
    SUM(CASE WHEN datediff('minute', START, STOP) = 0 THEN 1 ELSE 0 END) AS zero_los_rows,
    MIN(datediff('minute', START, STOP)) AS min_los_minutes,
    MAX(datediff('minute', START, STOP)) AS max_los_minutes
FROM 'encounters.csv'
WHERE ENCOUNTERCLASS = 'emergency'
  AND START IS NOT NULL
  AND STOP IS NOT NULL;

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
SELECT *
FROM ed_cohort
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
SELECT COUNT(*) AS cleaned_ed_visit_count
FROM ed_cohort;