
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "benchmarks/results/baseline"
WORKLOAD = ROOT / "queries/workload_30.sql"
OUTPUT = ROOT / "docs/03_baseline_timings.md"

# Read the actual query descriptions from the supplied workload.
descriptions = {}
lines = WORKLOAD.read_text().splitlines()

for i, line in enumerate(lines):
    match = re.match(r"-- @(R\d{2}|W\d{2})$", line.strip())
    if match:
        query_id = match.group(1)
        description = lines[i + 1].strip().removeprefix("--").strip()
        descriptions[query_id] = description.strip('"')

# Read measured averages and scan nodes.
with (RESULTS / "summary.csv").open() as f:
    summary = {row["query_id"]: row for row in csv.DictReader(f)}

# Query-specific observations based on the actual SQL and execution plans.
observations = {
    "R01": "Scans the large viewing_activity table to find one profile's unfinished views.",
    "R02": "An index lookup on episodes makes this small, title-specific aggregation fast.",
    "R03": "Scans viewing activity and filters by date before grouping viewers by title.",
    "R04": "Sequential scans and joins across the content and genre tables are inexpensive at this dataset size.",
    "R05": "The leading-wildcard ILIKE search generally cannot use a normal B-tree index.",
    "R06": "The composite primary-key index on my_list supports the profile lookup efficiently.",
    "R07": "The episode-number index makes finding the next episode very fast.",
    "R08": "Scans and groups viewing activity to identify binge sessions.",
    "R09": "Joins and aggregates a large viewing-activity dataset by genre.",
    "R10": "Scans accounts because lower(email) does not directly match a normal email index.",
    "R11": "Joins invoices and accounts while filtering failed invoices and account status.",
    "R12": "Scans accounts and groups cancellation records by month.",
    "R13": "Combines an indexed episode lookup with a scan of viewing activity for the NOT IN check.",
    "R14": "Joins viewing activity, profiles and titles, then evaluates maturity-rating conditions.",
    "R15": "Scans accounts and joins the small plans table to calculate revenue.",
    "R16": "Joins and groups the large viewing-activity table across accounts, profiles and plans.",
    "R17": "Scans ratings and joins titles to calculate rating percentages.",
    "R18": "Scans and aggregates viewing activity by month and device.",
    "R19": "Two correlated subqueries repeatedly scan all viewing_activity rows for each Netflix Original, causing the largest cost.",
    "R20": "Scans my_list and joins titles before grouping and sorting additions.",
    "R21": "Scans accounts to filter accounts on hold by billing date.",
    "R22": "Scans the relatively small titles table to find titles leaving in July.",
    "R23": "A large OFFSET requires PostgreSQL to process and discard many earlier rows before returning the requested page.",
    "R24": "Scans profiles to find the small set belonging to one account.",
    "R25": "Uses the title_genres primary-key index for one side of the self-join; the remaining scan and grouping are relatively small.",
    "W01": "Uses the episode index to locate the episode before inserting a viewing record.",
    "W02": "A small insert with conflict handling on the composite primary key.",
    "W03": "Looks up the STANDARD plan and updates the account through its primary key.",
    "W04": "Scans active accounts and joins plans to generate invoices for many rows.",
    "W05": "Scans accounts and checks matching failed invoices through an EXISTS subquery."
}

def get_run_times(query_id):
    path = RESULTS / f"{query_id}.txt"
    content = path.read_text()
    times = re.findall(r"Execution Time:\s*([\d.]+)\s*ms", content)
    if len(times) != 3:
        raise ValueError(
            f"{query_id}: expected 3 execution times, found {len(times)}"
        )
    return [float(value) for value in times]

query_ids = (
    [f"R{i:02d}" for i in range(1, 26)]
    + [f"W{i:02d}" for i in range(1, 6)]
)

report = [
    "# Phase 3: Baseline Query Benchmark",
    "",
    "## 1. Benchmark Environment",
    "",
    "- Database: PostgreSQL",
    "- Database name: `netflix`",
    "- Dataset: Netflix streaming seed data",
    "- Workload: `queries/workload_30.sql`",
    "- Execution method: `EXPLAIN (ANALYZE, BUFFERS)`",
    "- Runs per query: 3",
    "- Benchmark phase: `before` (unoptimized baseline)",
    "- Write queries: executed inside transactions and rolled back",
    "",
    "## 2. Execution Timings",
    "",
    "All values below are measured execution times in milliseconds. "
    "The average is taken from the benchmark summary CSV.",
    "",
    "| Query | Type | Description | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |",
    "|---|---|---|---:|---:|---:|---:|"
]

for query_id in query_ids:
    row = summary[query_id]
    runs = get_run_times(query_id)
    description = descriptions.get(query_id, query_id).replace("|", "\\|")

    report.append(
        f"| {query_id} | {row['type']} | {description} "
        f"| {runs[0]:.3f} | {runs[1]:.3f} | {runs[2]:.3f} "
        f"| {float(row['avg_ms']):.3f} |"
    )

report.extend([
    "",
    "## 3. Scan Types and Performance Observations",
    "",
    "| Query | Scan type(s) reported | Performance observation |",
    "|---|---|---|"
])

for query_id in query_ids:
    row = summary[query_id]
    scans = row["scan_nodes"].replace("|", ",").replace("|", "\\|")
    report.append(
        f"| {query_id} | {scans or 'No scan reported'} "
        f"| {observations[query_id]} |"
    )

report.extend([
    "",
    "## 4. Key Findings",
    "",
    "- R19 is the slowest read query. Its correlated subqueries repeatedly "
    "scan the large `viewing_activity` table.",
    "- R23 is a candidate for pagination optimization because its large "
    "OFFSET requires processing many preceding rows.",
    "- R16 performs joins and aggregation over a large viewing-activity dataset.",
    "- Queries using suitable primary-key or unique indexes, such as R02, "
    "R06 and R07, have very low execution times.",
    "- Sequential scans are visible in several queries. They are not "
    "automatically inefficient, especially on smaller tables, but scans "
    "over large tables are candidates for investigation.",
    "",
    "## 5. Baseline Result Files",
    "",
    "- `benchmarks/results/baseline/summary.csv` contains the benchmark summary.",
    "- `benchmarks/results/baseline/R01.txt` through `R25.txt` contain "
    "the raw read-query execution plans.",
    "- `benchmarks/results/baseline/W01.txt` through `W05.txt` contain "
    "the raw write-query execution plans.",
    "",
    "## 6. Conclusion",
    "",
    "The baseline benchmark successfully executed all 30 workload queries "
    "three times each. The recorded timings and execution plans provide "
    "a reference point for evaluating query and index optimizations in "
    "the next phase.",
    ""
])

OUTPUT.write_text("\n".join(report))
print(f"Created: {OUTPUT}")
print(f"Queries documented: {len(query_ids)}")
print(f"Raw execution plans checked: {len(query_ids) * 3} execution times")
