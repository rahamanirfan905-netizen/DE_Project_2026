# Netflix Database Scalability Report

## Part 1 – Large Dataset Preparation and Analysis

**Prepared by:** Prithwiraj Mitra
**Database:** netflix_large
**PostgreSQL:** 18.7
**Operating System:** macOS

### 1. Large Dataset Overview

The faculty released the Phase 5 large dataset
for the Netflix Streaming Database.

The compressed archive was approximately 131 MB.
After extraction, the large_data directory occupied
approximately 625 MB.

The dataset contains 11 CSV files and 11,124,198
data records, excluding CSV header rows.

### 2. Database Preparation

A separate PostgreSQL database named netflix_large
was created to preserve the original netflix seed
database.

The existing project schema was reused:

- sql/01_schema.sql

A temporary copy of the existing loading script
was prepared by changing the dataset directory
from seed_data/ to large_data/.

The original sql/02_load_data.sql was not modified.

All 11 CSV files were imported successfully using
PostgreSQL COPY commands.

The import was performed within a transaction.
ANALYZE completed successfully, followed by COMMIT.

### 3. Large Dataset Row Counts

| Table | Actual Rows |
|---|---:|
| plans | 4 |
| accounts | 500000 |
| profiles | 1500000 |
| genres | 15 |
| titles | 60000 |
| title_genres | 119166 |
| episodes | 400000 |
| viewing_activity | 4012819 |
| ratings | 674605 |
| my_list | 1199989 |
| invoices | 2657600 |
| Total | 11124198 |

All 11 PostgreSQL table counts were verified
against the corresponding CSV files.

### 4. Seed Dataset vs Large Dataset

| Measurement | Seed | Large |
|---|---:|---:|
| Total records | 556332 | 11124198 |
| Database size | 73 MB | 1004 MB |

The large dataset contains approximately 20 times
the seed dataset's records.

Database storage increased approximately 13.75
times based on the displayed database sizes.

### 5. Viewing Activity Date Range

The viewing_activity table contains 4,012,819 rows.

Earliest viewing:
2025-01-01 00:00:00+05:30

Latest viewing:
2026-07-01 02:19:02+05:30

The dataset contains viewing records across
19 monthly periods.

### 6. Monthly Viewing Activity Distribution

| Month | Records |
|---|---:|
| Jan 2025 | 228692 |
| Feb 2025 | 205963 |
| Mar 2025 | 227473 |
| Apr 2025 | 220462 |
| May 2025 | 228139 |
| Jun 2025 | 220625 |
| Jul 2025 | 228032 |
| Aug 2025 | 228480 |
| Sep 2025 | 221134 |
| Oct 2025 | 227851 |
| Nov 2025 | 221024 |
| Dec 2025 | 228145 |
| Jan 2026 | 227343 |
| Feb 2026 | 205395 |
| Mar 2026 | 227551 |
| Apr 2026 | 219479 |
| May 2026 | 227067 |
| Jun 2026 | 219843 |
| Jul 2026 | 121 |

The July 2026 data represents a partial month.

### 7. Table and Index Storage

Initial storage measurements after importing
the large dataset and before applying the
additional CP3 optimization indexes:

| Table | Table Size | Index Size | Total |
|---|---:|---:|---:|
| viewing_activity | 266 MB | 86 MB | 352 MB |
| invoices | 173 MB | 57 MB | 230 MB |
| profiles | 95 MB | 32 MB | 127 MB |
| accounts | 50 MB | 50 MB | 100 MB |
| my_list | 51 MB | 26 MB | 77 MB |
| ratings | 38 MB | 14 MB | 53 MB |
| episodes | 27 MB | 17 MB | 44 MB |
| titles | 5960 kB | 1328 kB | 7320 kB |
| title_genres | 4224 kB | 2624 kB | 6880 kB |
| plans | 8192 bytes | 32 kB | 40 kB |
| genres | 8192 bytes | 32 kB | 40 kB |

The viewing_activity table occupies the most
storage and is the primary candidate for
date-based partitioning.

### 8. Transition to Partitioning Analysis

The large database has been created and verified.

The following information was used for
the partitioning analysis:

- Database: netflix_large
- Total records: 11,124,198
- Viewing activity records: 4,012,819
- First viewing date: 2025-01-01
- Last viewing date: 2026-07-01
- Database size: 1004 MB

The partitioning and scalability analysis is documented
in Part 2 below.

## Part 2 – Partitioning and Performance Analysis

## 1. Objective

The objective of this experiment is to evaluate how date-based partitioning improves query performance on a large Netflix streaming dataset. We compare the original viewing_activity table with a partitioned version using a date-range query.

## 2. Dataset Scale

The experiment was conducted using the large dataset in PostgreSQL.

| Table | Rows |
|---|---:|
| accounts | 500,000 |
| profiles | 1,500,000 |
| titles | 60,000 |
| episodes | 400,000 |
| viewing_activity | 4,012,819 |
| ratings | 674,605 |
| my_list | 1,199,989 |
| invoices | 2,657,600 |

The dataset contains approximately 11.12 million rows across the listed tables and other supporting tables.

## 3. Partitioning Strategy

The viewing_activity table was partitioned using RANGE partitioning on the started_at column.

A separate partitioned table named viewing_activity_partitioned was created to preserve the original table for comparison.

Monthly partitions were created from January 2025 through July 2026, allowing PostgreSQL to eliminate partitions that do not match the query date range.

The partitioned table uses a composite primary key consisting of view_id and started_at.
## 4. Partition Pruning Verification

Partition pruning was tested using a date-range query to retrieve viewing activity records from June 2026.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*)
FROM netflix.viewing_activity_partitioned
WHERE started_at >= '2026-06-01'
  AND started_at < '2026-07-01';
```

The execution plan showed that PostgreSQL accessed the June 2026 partition instead of scanning all monthly partitions. This confirmed successful partition pruning for the selected date range.

## 5. Benchmark Results

The query was executed multiple times on both the original and partitioned tables.

| Table | Runs | Average Execution Time |
|---|---:|---:|
| Original viewing_activity | 4 | 99.588 ms |
| Partitioned viewing_activity | 3 | 31.636 ms |

The partitioned table achieved a lower average execution time for the selected date-range query.

## 6. Performance Analysis

The average execution time decreased from 99.588 ms to 31.636 ms.

- Original average: 99.588 ms
- Partitioned average: 31.636 ms
- Execution time reduction: approximately 68.23%
- Speedup: approximately 3.15×

The original execution plan showed a Parallel Seq Scan on the original viewing_activity table. It also removed 1,264,325 rows through the date filter.

The partitioned execution plan showed a Parallel Seq Scan on the June 2026 partition (viewing_activity_p_2026_06). PostgreSQL therefore avoided scanning irrelevant monthly partitions.

## 7. Observations and Limitations

- Monthly range partitioning was effective for date-based queries.
- Partition pruning reduced the data scanned for the selected month.
- The experiment used a large dataset containing approximately 4 million viewing activity records.
- The original table was measured four times, while the partitioned table was measured three times.
- Execution times can vary due to caching, database load, and system resources.
- This was a targeted date-range experiment and not a complete evaluation of all 30 workload queries.

## 8. Conclusion

The experiment demonstrates that monthly range partitioning can improve the performance of date-based queries on large datasets.

For the June 2026 query, the partitioned table achieved an average execution time of 31.636 ms compared with 99.588 ms on the original table. PostgreSQL successfully pruned irrelevant partitions and scanned only the relevant monthly partition.

Partitioning is therefore a useful scalability technique for large time-based datasets such as streaming activity logs, particularly when queries frequently filter records by date.

