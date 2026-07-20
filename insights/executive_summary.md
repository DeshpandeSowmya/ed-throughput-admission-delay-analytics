# Executive Summary

## Project Summary

This project analyzes synthetic emergency department encounter data to identify where throughput pressure is concentrated and which patient, payer, and operational segments are associated with longer ED stays.

Using SQL in Deepnote and Tableau for visualization, the project builds an ED-only analytical dataset, calculates encounter-level throughput metrics, and produces an executive dashboard for healthcare operations review.

## Main Findings

- The ED LOS distribution is highly skewed: median ED LOS was **60 minutes**, while the average ED LOS was **605.7 minutes**.
- **10.92%** of ED visits exceeded 4 hours, indicating a meaningful long-stay subgroup.
- The **evening shift** showed the highest average ED LOS (**1005.4 minutes**) and the highest long-stay rate (**16.39%**).
- Payer groups such as **Cigna Health**, **UnitedHealthcare**, and **NO_INSURANCE** showed notably higher average ED LOS values in the synthetic cohort.
- Clinical reason groups such as **sepsis**, **overdose**, and **pneumonia** were associated with the highest average ED LOS.

## Operational Implications

- Focus workflow review on the smaller subset of extreme long-stay encounters rather than only the typical ED visit.
- Review evening shift throughput processes first, because that period shows the strongest concentration of delay burden.
- Use subgroup findings to prioritize payer and clinical categories that appear most associated with throughput risk.

## Limitations

- The data are synthetic and should be interpreted as a portfolio demonstration, not a real hospital performance assessment.
- The project analyzes ED throughput and delay concentration, not true inpatient boarding based on bed management timestamps.
