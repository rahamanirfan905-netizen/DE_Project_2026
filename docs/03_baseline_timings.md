# Phase 3: Baseline Query Benchmark

## 1. Benchmark Environment

- Database: PostgreSQL
- Database name: `netflix`
- Dataset: Netflix streaming seed data
- Workload: `queries/workload_30.sql`
- Execution method: `EXPLAIN (ANALYZE, BUFFERS)`
- Runs per query: 3
- Benchmark phase: `before` (unoptimized baseline)
- Write queries: executed inside transactions and rolled back

## 2. Execution Timings

All values below are measured execution times in milliseconds. The average is taken from the benchmark summary CSV.

| Query | Type | Description | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---|---:|---:|---:|---:|
| R01 | READ | Continue Watching" row: the latest unfinished viewing per title for profile 7043 | 20.802 | 12.002 | 10.564 | 14.456 |
| R02 | READ | Title page: seasons of series 2909 with the number of episodes in each | 0.116 | 0.087 | 0.121 | 0.108 |
| R03 | READ | Top 10 in India today" row: most-watched titles on 30 June 2026 | 17.454 | 10.873 | 9.497 | 12.608 |
| R04 | READ | Genre row for a kids profile: Comedy titles rated U or UA7, newest additions first | 1.622 | 1.506 | 1.530 | 1.553 |
| R05 | READ | Search: titles whose name contains "love | 2.009 | 1.680 | 1.629 | 1.773 |
| R06 | READ | My List" row for profile 7393 | 0.236 | 0.221 | 0.235 | 0.231 |
| R07 | READ | Autoplay: the next episode of series 2909 after season 1 episode 4 | 0.118 | 0.110 | 0.113 | 0.114 |
| R08 | READ | Insights: binge sessions in June 2026 (3+ episodes of one series by one profile on one day) | 23.341 | 14.910 | 12.887 | 17.046 |
| R09 | READ | Content analytics: completion rate per genre (2026) | 37.945 | 29.928 | 24.996 | 30.956 |
| R10 | READ | Sign-in: find the account by email, ignoring case | 2.912 | 2.903 | 3.167 | 2.994 |
| R11 | READ | Payments: active accounts whose June 2026 invoice failed (retry list) | 8.666 | 8.516 | 8.239 | 8.474 |
| R12 | READ | Retention: cancellations per month in 2026 and average tenure (days) of those accounts | 1.455 | 1.351 | 1.378 | 1.395 |
| R13 | READ | Content team: episodes of series 2523 that nobody has watched | 20.392 | 20.334 | 18.639 | 19.788 |
| R14 | READ | Compliance: kids profiles that watched titles above their maturity limit | 25.388 | 23.161 | 21.106 | 23.218 |
| R15 | READ | Finance: active accounts and monthly recurring revenue per plan | 4.573 | 4.708 | 4.908 | 4.730 |
| R16 | READ | Account sharing check: accounts with more profiles watching in the same hour than their plan's streams | 117.198 | 116.212 | 116.834 | 116.748 |
| R17 | READ | Content strategy: share of "LOVE" ratings for Netflix Originals vs licensed titles | 5.682 | 5.891 | 5.987 | 5.853 |
| R18 | READ | Device analytics: viewing hours per device per month in 2026 | 32.315 | 27.480 | 26.335 | 28.710 |
| R19 | READ | Originals report: total views and the most recent view of every Netflix Original | 5642.878 | 5690.244 | 5758.955 | 5697.359 |
| R20 | READ | Marketing: 10 titles added to the most My Lists in June 2026 | 3.262 | 3.318 | 3.579 | 3.386 |
| R21 | READ | Payments: accounts on hold whose billing date has already passed | 1.250 | 1.744 | 1.032 | 1.342 |
| R22 | READ | Last chance to watch" row: licensed titles leaving in July 2026 | 0.404 | 0.484 | 0.398 | 0.429 |
| R23 | READ | Support console: all viewing activity, newest first, page 6,001 (25 per page) | 62.962 | 38.880 | 36.566 | 46.136 |
| R24 | READ | Who's watching?" screen: profiles of account 1409 | 1.782 | 1.949 | 1.929 | 1.887 |
| R25 | READ | More like this": titles sharing at least 2 genres with series 2909 | 0.825 | 0.629 | 0.620 | 0.691 |
| W01 | WRITE | Player: profile 7043 starts episode S1E5 of series 2909 | 0.344 | 0.283 | 1.030 | 0.552 |
| W02 | WRITE | + My List": profile 7043 adds series 2523 | 0.811 | 1.298 | 1.152 | 1.087 |
| W03 | WRITE | Account settings: account 1409 downgrades to the STANDARD plan | 0.953 | 0.762 | 0.762 | 0.826 |
| W04 | WRITE | Monthly billing run: create July 2026 invoices for every active account | 99.214 | 69.434 | 67.713 | 78.787 |
| W05 | WRITE | Dunning: put active accounts whose latest invoice failed on hold | 13.592 | 11.140 | 11.621 | 12.118 |

## 3. Scan Types and Performance Observations

| Query | Scan type(s) reported | Performance observation |
|---|---|---|
| R01 | Seq Scan on viewing_activity , Index Scan using titles_pkey on titles | Scans the large viewing_activity table to find one profile's unfinished views. |
| R02 | Index Scan using uq_episode_number on episodes | An index lookup on episodes makes this small, title-specific aggregation fast. |
| R03 | Seq Scan on viewing_activity , Index Scan using titles_pkey on titles | Scans viewing activity and filters by date before grouping viewers by title. |
| R04 | Seq Scan on titles , Seq Scan on title_genres , Seq Scan on genres | Sequential scans and joins across the content and genre tables are inexpensive at this dataset size. |
| R05 | Seq Scan on titles | The leading-wildcard ILIKE search generally cannot use a normal B-tree index. |
| R06 | Index Scan using my_list_pkey on my_list , Index Scan using titles_pkey on titles | The composite primary-key index on my_list supports the profile lookup efficiently. |
| R07 | Index Scan using uq_episode_number on episodes | The episode-number index makes finding the next episode very fast. |
| R08 | Seq Scan on viewing_activity | Scans and groups viewing activity to identify binge sessions. |
| R09 | Seq Scan on viewing_activity , Seq Scan on title_genres , Seq Scan on genres | Joins and aggregates a large viewing-activity dataset by genre. |
| R10 | Seq Scan on accounts | Scans accounts because lower(email) does not directly match a normal email index. |
| R11 | Seq Scan on accounts , Seq Scan on invoices | Joins invoices and accounts while filtering failed invoices and account status. |
| R12 | Seq Scan on accounts | Scans accounts and groups cancellation records by month. |
| R13 | Index Scan using uq_episode_number on episodes , Seq Scan on viewing_activity | Combines an indexed episode lookup with a scan of viewing activity for the NOT IN check. |
| R14 | Seq Scan on viewing_activity , Seq Scan on profiles , Seq Scan on titles | Joins viewing activity, profiles and titles, then evaluates maturity-rating conditions. |
| R15 | Seq Scan on accounts , Seq Scan on plans | Scans accounts and joins the small plans table to calculate revenue. |
| R16 | Seq Scan on viewing_activity , Seq Scan on profiles , Seq Scan on accounts , Seq Scan on plans | Joins and groups the large viewing-activity table across accounts, profiles and plans. |
| R17 | Seq Scan on ratings , Seq Scan on titles | Scans ratings and joins titles to calculate rating percentages. |
| R18 | Seq Scan on viewing_activity | Scans and aggregates viewing activity by month and device. |
| R19 | Seq Scan on titles , Seq Scan on viewing_activity | Two correlated subqueries repeatedly scan all viewing_activity rows for each Netflix Original, causing the largest cost. |
| R20 | Seq Scan on my_list , Seq Scan on titles | Scans my_list and joins titles before grouping and sorting additions. |
| R21 | Seq Scan on accounts | Scans accounts to filter accounts on hold by billing date. |
| R22 | Seq Scan on titles | Scans the relatively small titles table to find titles leaving in July. |
| R23 | Seq Scan on viewing_activity | A large OFFSET requires PostgreSQL to process and discard many earlier rows before returning the requested page. |
| R24 | Seq Scan on profiles | Scans profiles to find the small set belonging to one account. |
| R25 | Seq Scan on title_genres , Index Only Scan using title_genres_pkey on title_genres | Uses the title_genres primary-key index for one side of the self-join; the remaining scan and grouping are relatively small. |
| W01 | Index Scan using uq_episode_number on episodes | Uses the episode index to locate the episode before inserting a viewing record. |
| W02 | (no scan) | A small insert with conflict handling on the composite primary key. |
| W03 | Seq Scan on plans , Index Scan using accounts_pkey on accounts | Looks up the STANDARD plan and updates the account through its primary key. |
| W04 | Seq Scan on accounts , Seq Scan on plans | Scans active accounts and joins plans to generate invoices for many rows. |
| W05 | Seq Scan on accounts , Seq Scan on invoices | Scans accounts and checks matching failed invoices through an EXISTS subquery. |

## 4. Key Findings

- R19 is the slowest read query. Its correlated subqueries repeatedly scan the large `viewing_activity` table.
- R23 is a candidate for pagination optimization because its large OFFSET requires processing many preceding rows.
- R16 performs joins and aggregation over a large viewing-activity dataset.
- Queries using suitable primary-key or unique indexes, such as R02, R06 and R07, have very low execution times.
- Sequential scans are visible in several queries. They are not automatically inefficient, especially on smaller tables, but scans over large tables are candidates for investigation.

## 5. Baseline Result Files

- `benchmarks/results/baseline/summary.csv` contains the benchmark summary.
- `benchmarks/results/baseline/R01.txt` through `R25.txt` contain the raw read-query execution plans.
- `benchmarks/results/baseline/W01.txt` through `W05.txt` contain the raw write-query execution plans.

## 6. Conclusion

The baseline benchmark successfully executed all 30 workload queries three times each. The recorded timings and execution plans provide a reference point for evaluating query and index optimizations in the next phase.
