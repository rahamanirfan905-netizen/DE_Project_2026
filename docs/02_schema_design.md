# Schema design and data findings

## Source inspection

All 11 CSV files were inspected directly after extracting `seed_data.zip`. The observed row counts are: plans 4, accounts 25,000, profiles 75,000, genres 15, titles 3,000, title_genres 5,963, episodes 20,000, viewing_activity 200,401, ratings 33,900, my_list 59,992, and invoices 133,057. These match the brief.

Nulls were found only where expected: `accounts.phone` 4,888, `accounts.cancelled_on` 22,021, `accounts.next_billing_date` 2,979, `titles.runtime_min` 1,000, `titles.leaving_on` 2,738, `viewing_activity.episode_id` 93,056, and `invoices.paid_at` 4,764. All other exported fields are populated.

## Data dictionary

| Table | Columns and types | Key constraints | Rationale |
|---|---|---|---|
| plans | plan_id integer; plan_name text; monthly_price_inr numeric(8,2); max_streams smallint; max_resolution text; has_ads boolean | PK plan_id; UNIQUE plan_name | A plan is a stable subscription reference. Price and resolution are attributes, not identifiers. |
| accounts | account_id integer; email text; phone text; country_code char(2); plan_id integer; signup_date date; status text; cancelled_on date; next_billing_date date | PK account_id; email/phone unique; plan FK | One household billing identity. Phone is nullable. |
| profiles | profile_id integer; account_id integer; profile_name text; is_kids boolean; maturity_limit text; language text; created_at timestamptz | PK profile_id; FK account; UNIQUE(account_id, profile_name) | A profile belongs to one account; the compound unique key prevents duplicate profile labels per account. |
| genres | genre_id integer; genre_name text | PK genre_id; UNIQUE genre_name | Controlled genre lookup. |
| titles | title_id integer; title_type text; name text; release_year smallint; maturity_rating text; original_language text; runtime_min smallint; is_netflix_original boolean; added_on date; leaving_on date | PK title_id | Catalogue movies and series. A title name is not treated as globally unique because remakes and regional variants can share one. Runtime is nullable only for series. |
| title_genres | title_id integer; genre_id integer | PK(title_id, genre_id); both FKs | Resolves the title--genre many-to-many relationship. |
| episodes | episode_id integer; title_id integer; season_no smallint; episode_no smallint; episode_title text; runtime_min smallint; release_date date | PK episode_id; FK title; UNIQUE(title_id, season_no, episode_no) | An episode is uniquely positioned within a series season. |
| viewing_activity | view_id bigint; profile_id integer; title_id integer; episode_id integer; started_at timestamptz; duration_watched_sec integer; device_type text; completed boolean | PK view_id; profile/title FKs; composite episode/title FK | `episode_id` is null for movies; the composite FK prevents an episode from being paired with a different title. |
| ratings | profile_id integer; title_id integer; rating text; rated_at timestamptz | PK(profile_id, title_id); both FKs | At most one current rating per profile/title. |
| my_list | profile_id integer; title_id integer; added_at timestamptz | PK(profile_id, title_id); both FKs | At most one saved-title relationship per profile/title. |
| invoices | invoice_id bigint; account_id integer; billing_period_start date; amount_inr numeric(8,2); status text; paid_at timestamptz | PK invoice_id; FK account; UNIQUE(account_id, billing_period_start) | One invoice per account/month. Payment time is nullable for failures. |

`sql/01_schema.sql` has no manually created performance indexes. PostgreSQL creates the indexes required by primary keys and unique constraints only.

## Referential actions and business rules

Plans, genres, titles, episodes, accounts with invoices, and profiles with viewing history use `RESTRICT` where deletion would erase or invalidate retained business history. Removing an account cascades to its profiles; removing a profile cascades to its mutable ratings and My List entries. Removing a title cascades only its title--genre junction records. This is intentionally conservative.

The schema has more than twelve meaningful `CHECK` constraints. They validate positive identifiers and prices, plan names, stream count, email lower-case export form, phone format, account status/date combinations, cancellation chronology, allowed maturity ratings/languages, kids limits, title type/runtime rules, original/leaving rules, episode numbering/runtime, watched duration, devices, rating values, monthly invoice dates, invoice payment states, and payment chronology.

The export does not carry a `title_type` column in `episodes`, so a plain foreign key cannot declaratively require an episode's title to be a `SERIES` without introducing an extra non-export column or a trigger. The inspected data satisfies this rule; it is recorded as an application/import validation rule rather than fabricating a CSV column.

## Functional dependencies and normal form

Every relation is in 3NF. Tables whose only nontrivial dependency has a candidate-key determinant are also BCNF: `plans` (`plan_id ->` all; `plan_name ->` all), `accounts` (`account_id ->` all; `email ->` all; nullable `phone ->` all when present), `profiles` (`profile_id ->` all and `(account_id, profile_name) ->` all), `genres` (`genre_id -> genre_name`, `genre_name -> genre_id`), `titles` (`title_id ->` all), `title_genres` (key is all attributes), `episodes` (`episode_id ->` all and `(title_id, season_no, episode_no) ->` all), `viewing_activity` (`view_id ->` all), `ratings` (`(profile_id, title_id) -> rating, rated_at`), `my_list` (`(profile_id, title_id) -> added_at`), and `invoices` (`invoice_id ->` all and `(account_id, billing_period_start) ->` all).

`viewing_activity.title_id` is redundant when `episode_id` is present, but it is required for movie views and supports a title-level event record. `completed` is denormalized relative to watched duration and runtime, but it records product completion semantics. `invoices.amount_inr` is redundant relative to a current plan price, but must be retained as historical billing evidence.

## ER diagram

The Mermaid source is [`../diagrams/er_diagram.mmd`](../diagrams/er_diagram.mmd); the rendered CP1 image is `diagrams/er_diagram.png`.

## Integrity checks performed in PostgreSQL

The source-file checks below were also run as SQL checks after loading all data into a temporary PostgreSQL 16.15 instance.

| Check | Result |
|---|---:|
| Orphan profile-to-account foreign-key references | 0 |
| Viewing rows whose episode belongs to a different title | 0 |
| Episodes whose title is not a series | 0 |
| Accounts outside the allowed 1--5 profile range | 0 (observed range: 1--5) |
| Duplicate `(title_id, genre_id)`, `(profile_id, title_id)` in ratings/My List, `(account_id, billing_period_start)`, or `(title_id, season_no, episode_no)` | 0 |
| Kids profiles with a limit above U/UA7 | 0 |
| Originals with a leaving date | 0 |
| Invoice payment-state violations or billing dates not on the first of a month | 0 |

No source data problem was found in the tested rules.

## Validation status

`psql` 16.15 was available. The normal local socket had no running server, so validation used an isolated temporary PostgreSQL 16.15 cluster under `/private/tmp`. `sql/01_schema.sql` ran top-to-bottom successfully, `sql/02_load_data.sql` imported every file successfully, `ANALYZE` completed, all row counts matched, and the unchanged `queries/workload_30.sql` completed successfully. The temporary cluster was stopped and removed afterward. No benchmark timings are claimed.
