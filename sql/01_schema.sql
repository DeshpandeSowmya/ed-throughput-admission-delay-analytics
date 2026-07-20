SELECT *
FROM 'patients.csv'
LIMIT 10;

SELECT *
FROM 'encounters.csv'
LIMIT 10;

SELECT ENCOUNTERCLASS, COUNT(*) AS visit_count
FROM 'encounters.csv'
GROUP BY ENCOUNTERCLASS
ORDER BY visit_count DESC;

SELECT 'patients' AS table_name, COUNT(*) AS row_count
FROM 'patients.csv'

UNION ALL

SELECT 'encounters' AS table_name, COUNT(*) AS row_count
FROM 'encounters.csv'

UNION ALL

SELECT 'conditions' AS table_name, COUNT(*) AS row_count
FROM 'conditions.csv'

UNION ALL

SELECT 'payers' AS table_name, COUNT(*) AS row_count
FROM 'payers.csv'

UNION ALL

SELECT 'organizations' AS table_name, COUNT(*) AS row_count
FROM 'organizations.csv'

UNION ALL

SELECT 'providers' AS table_name, COUNT(*) AS row_count
FROM 'providers.csv';