# CareLoop Clinics — No-Show Guard

**Repository:** `<<PASTE YOUR PUBLIC GITHUB REPO LINK HERE>>`

From a raw booking export to a cleaned table, SQL evidence of where no-shows cluster, a risk model the front desk can use the evening before, and AI-extracted reasons from call-centre notes.

**Business question:** Which appointments are most likely to be missed, why do patients miss them, and what should CareLoop do first?

---

## Summary (one finding per Part)

1. **Data:** 1,020 raw rows → **990 clean bookings** after removing 20 duplicates, 6 unreadable dates and 4 blank statuses; **218 no-shows (22.0%)**.
2. **SQL:** no-show risk climbs with lead time, from **16.2%** for bookings made 1–7 days ahead to **30.0%** at 15–30 days and **60.5%** at 31+ days.
3. **Model:** logistic regression ranks risk best (**test ROC-AUC 0.789**). At a threshold of **0.35** it flags 49 of 198 test bookings and catches **57%** of the real no-shows. In this model, a reminder is associated with about **69% lower** no-show odds.
4. **GenAI:** `<<from notes_analysed.csv: e.g. "X of the 9 classified notes cite a forgotten or missing reminder…">>`. Both notes classed as `forgot_or_no_reminder` (N001, N007) belong to appointments with `reminder_sent = No`, as do **5 of the 10** notes overall.

## Recommendation

CareLoop should first make sure **every booking gets a reminder**, then use the risk score each evening to **phone the riskiest patients**. In the model, holding other factors constant, a reminder goes with about 69% lower odds of a no-show (odds × 0.31). In the follow-up notes, `<<your Part 4 count>>` patients said they forgot or never received a reminder, and both of those appointments had `reminder_sent = No`. Calls should go first to bookings made far ahead: the no-show rate is 30.0% at 15–30 days and 60.5% beyond 30 days, against 16.2% within a week. At the 0.35 threshold the model flags about 25% of bookings (49 of 198 in the test set), and 57% of those flags are real no-shows. Clinic-level follow-up should start with Hadapsar (27.3%) and Malviya Nagar (26.8%), which have both high rates and enough bookings to trust the figures. Gomti Nagar's 33.3% is the highest rate, but it rests on only 90 appointments.

## Model choice

- **Chosen model:** logistic regression (`StandardScaler` + `LogisticRegression` in a pipeline).
- **Why:** it had the highest 5-fold cross-validated ROC-AUC **on the training set** (**0.774**), ahead of the tuned random forest (0.767, `max_depth=3, n_estimators=200`), the default forest (0.747) and the depth-3 tree (0.678). The test set played no part in the choice.
- **Threshold 0.35:** chosen from out-of-fold training probabilities. F1 was 0.489 at 0.35 versus 0.347 at 0.5, and recall was 0.467 versus 0.249. A missed no-show costs an empty slot, while an extra call costs about a minute.
- **One-time test result:** ROC-AUC **0.789**, precision 0.571, recall 0.571, 49 flagged (see `test_risk_scores.csv`).
- In practice the threshold should be set by how many calls the front desk can make in an evening.

## Limitations

1. **Associations, not causes.** The data are observational. The reminder effect may partly reflect *who* receives reminders, not the reminder itself.
2. **Cleaning before the split.** The medians, quartiles and outlier fences were computed on all 990 rows, so the test rows had a small indirect influence on cleaning. The same patient can also appear in both train and test, and the split is random rather than past-to-future. Real-world performance may be lower than reported.
3. **Ten notes are an illustration.** The notes only show which reasons exist, not their share clinic-wide. Clinic-level rates also rest on 82–160 bookings each, so small differences between clinics are not reliable.

---

## Repository contents

| File | Part | What it is |
|---|---|---|
| `data/` | — | The three original files, unedited |
| `01_ingest_clean.ipynb` | 1 | Tasks 1.1–1.6: csv-module read, pandas cleaning, NumPy summary, Open-Meteo enrichment, export |
| `rejected_rows.json` | 1 | 32 rows that failed type conversion in Task 1.1 |
| `appointments_clean.csv` | 1 | 990 × 16 cleaned bookings (input to Parts 2–3) |
| `clinics_enriched.csv` | 1 | 8 clinics + `temp_c` from Open-Meteo |
| `load_data.sql` | 1 | 998 `INSERT` statements (8 clinics, then 990 appointments) |
| `02_queries.sql` | 2 | Schema, checks, duplicate-key test (error text as a comment) and Tasks 2.2–2.5 |
| `03_model.ipynb` | 3 | Tasks 3.1–3.5, plus the pandas check that matches the SQL clinic counts |
| `test_risk_scores.csv` | 3 | 198 test bookings: `appointment_id, no_show, risk_prob, flag` |
| `04_genai.ipynb` | 4 | Gemini classification, Pydantic validation, prompt comparison (key entered at run time; not stored) |
| `notes_analysed.csv` | 4 | 10 notes → structured reasons, with the raw model reply |

## How to reproduce

1. **Part 1:** run `01_ingest_clean.ipynb` in Google Colab with the three CSVs in `data/`.
2. **Part 2:** in MySQL Workbench, run the `CREATE` statements in `02_queries.sql`, then `load_data.sql`, then the remaining queries.
3. **Part 3:** run `03_model.ipynb`.
4. **Part 4:** run `04_genai.ipynb` and type the Gemini key when prompted.

Conventions: `random_state=42`, `test_size=0.2`, percentages to 1 decimal.
