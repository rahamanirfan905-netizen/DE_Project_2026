# CP3 optimization report — Team T0087

## Method and limits

The supplied 30-query workload was inspected and preserved. The baseline is the committed `benchmarks/results/baseline/summary.csv` (three runs). The optimized figures below are five actual `EXPLAIN (ANALYZE, BUFFERS)` runs per query, produced by `benchmarks/run_benchmark.sh` on PostgreSQL 16.15 with the same 11 seed CSVs and eight indexes from `sql/05_indexes.sql`. Write statements ran inside `BEGIN`/`ROLLBACK`. These are separate sessions; small timing differences can reflect cache and host load. Negative improvement is a regression, not hidden.

Only R19 SQL was changed. The other 29 query statements, including R13, are byte-for-byte copies of the faculty workload. R19 produced zero rows in the bidirectional `EXCEPT ALL` difference (including duplicates). R13's original `NOT IN` returns zero rows because movie views have NULL `episode_id`. A separate read-only test of `NOT EXISTS (SELECT 1 FROM viewing_activity v WHERE v.episode_id = e.episode_id)` returned eight unwatched episodes for series 2523. This is a **correctness recommendation**, not a result-equivalent optimization, so it is not used in the benchmarked workload. The faculty brief also asks to fix the wrong answer; changing R13 in the benchmark would conflict with its same-results requirement. The application/content report should adopt the corrected query after accepting the intended semantic change.

| Query | Before ms | Plan issue / action | After ms | Change | Result |
|---|---:|---|---:|---:|---|
| R01 | 14.456 | Event scan → partial profile/title/time index | 0.359 | +97.5% | Same |
| R02 | 0.108 | Existing episode unique index sufficient | 0.183 | −69.4% | Same |
| R03 | 12.608 | Event date scan → timestamp index | 0.699 | +94.5% | Same |
| R04 | 1.553 | Reverse genre lookup index | 0.361 | +76.8% | Same |
| R05 | 1.773 | Small title scan; no costly trigram extension | 0.428 | +75.9% | Same |
| R06 | 0.231 | Existing composite PK sufficient | 0.134 | +42.0% | Same |
| R07 | 0.114 | Existing episode unique index sufficient | 0.018 | +84.2% | Same |
| R08 | 17.046 | Date filter uses timestamp index | 2.328 | +86.3% | Same |
| R09 | 30.956 | Full-year aggregation still scans events | 36.725 | −18.6% | Same |
| R10 | 2.994 | `lower(email)` expression index | 0.347 | +88.4% | Same |
| R11 | 8.474 | Partial failed-invoice period/account index | 3.784 | +55.3% | Same |
| R12 | 1.395 | Small cancellation report; no extra index | 2.230 | −59.9% | Same |
| R13 | 19.788 | NULL-broken `NOT IN` preserved for equivalence | 20.182 | −2.0% | Same (wrong result; see above) |
| R14 | 23.218 | Broad compliance join still scans events | 22.767 | +1.9% | Same |
| R15 | 4.730 | Whole-account finance aggregation | 4.760 | −0.6% | Same |
| R16 | 116.748 | Global grouping still scans and sorts events | 159.775 | −36.9% | Same |
| R17 | 5.853 | Whole-rating aggregation | 5.454 | +6.8% | Same |
| R18 | 28.710 | Whole-year device aggregation | 28.374 | +1.2% | Same |
| R19 | 5697.359 | Repeated correlated scans → one grouped left join | 13.380 | +99.8% | Same; `EXCEPT ALL` 0 |
| R20 | 3.386 | Date/title covering index | 1.787 | +47.2% | Same |
| R21 | 1.342 | Small on-hold account scan | 1.280 | +4.6% | Same |
| R22 | 0.429 | Small title scan | 0.188 | +56.2% | Same |
| R23 | 46.136 | Timestamp index avoids full sort; OFFSET remains | 13.623 | +70.5% | Same |
| R24 | 1.887 | Account/creation index | 0.075 | +96.0% | Same |
| R25 | 0.691 | Reverse genre/title index | 0.508 | +26.5% | Same |
| W01 | 0.552 | Extra event-index maintenance | 0.872 | −58.0% | Same |
| W02 | 1.087 | Extra My List index maintenance | 0.502 | +53.8% | Same |
| W03 | 0.826 | Existing account PK lookup | 0.479 | +42.0% | Same |
| W04 | 78.787 | Whole-account billing insertion | 96.340 | −22.3% | Same |
| W05 | 12.118 | Partial failed-invoice index | 11.058 | +8.7% | Same |

R19 has by far the largest absolute gain; R23, R01 and R03 also have substantial gains. Representative before/after plan evidence:

| Query | Baseline plan | Optimized plan |
|---|---|---|
| R19 | Two correlated sequential event scans per Original, 610 loops each | One grouped parallel event scan and left join |
| R23 | Sequential scan and sort over 200,401 events | `viewing_started_at_desc_idx` index scan; still reads 150,025 rows |
| R10 | Sequential account scan | `accounts_lower_email_idx` expression index scan |
| R01 | Sequential event scan for one profile | Partial `viewing_unfinished_profile_title_time_idx` index scan |
| R03 | Sequential event scan for one day | `viewing_started_at_desc_idx` index scan |

The full before and after plans, including buffers and all run timings, are in `benchmarks/results/baseline/` and `benchmarks/results/optimized/`. R16, R09, R14 and R18 remain global aggregations; forcing indexes on these broad scans would not reliably improve them. R23 cannot be replaced with keyset pagination without changing the requested page semantics. R08's description says June, but its original SQL has no June upper bound; adding one would change results, so it was preserved.

## Write cost and index storage

W01 and W04 regressed in the measured averages: W01 by 0.320 ms (58.0% relative to its tiny baseline), W04 by 17.553 ms (22.3%). Extra indexes add insertion maintenance, although cache and host load also vary between benchmark sessions. The W04 increase merits follow-up before claiming the write cost acceptable at scale. Table below records `pg_relation_size` after load and index creation; sizes are rounded by PostgreSQL.

| Index | Size | Table size |
|---|---:|---:|
| viewing_unfinished_profile_title_time_idx | 2656 kB | 14 MB |
| viewing_started_at_desc_idx | 4416 kB | 14 MB |
| viewing_episode_present_idx | 1136 kB | 14 MB |
| accounts_lower_email_idx | 1224 kB | 2840 kB |
| invoices_failed_period_account_idx | 128 kB | 16 MB |
| my_list_added_title_idx | 1856 kB | 2600 kB |
| profiles_account_created_idx | 2336 kB | 4864 kB |
| title_genres_genre_title_idx | 152 kB | 216 kB |

The workload file, baseline summary and plans were not edited for CP3. The optimized summary contains all 30 rows and the helper script's `query_id,type,avg_ms,median_ms,min_ms,max_ms,scan_nodes` format.
