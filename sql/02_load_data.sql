-- Run from the repository root with psql: psql -d <database> -f sql/02_load_data.sql
SET search_path TO netflix;

\copy plans FROM 'seed_data/plans.csv' WITH (FORMAT csv, HEADER true)
\copy accounts FROM 'seed_data/accounts.csv' WITH (FORMAT csv, HEADER true)
\copy profiles FROM 'seed_data/profiles.csv' WITH (FORMAT csv, HEADER true)
\copy genres FROM 'seed_data/genres.csv' WITH (FORMAT csv, HEADER true)
\copy titles FROM 'seed_data/titles.csv' WITH (FORMAT csv, HEADER true)
\copy title_genres FROM 'seed_data/title_genres.csv' WITH (FORMAT csv, HEADER true)
\copy episodes FROM 'seed_data/episodes.csv' WITH (FORMAT csv, HEADER true)
\copy viewing_activity FROM 'seed_data/viewing_activity.csv' WITH (FORMAT csv, HEADER true)
\copy ratings FROM 'seed_data/ratings.csv' WITH (FORMAT csv, HEADER true)
\copy my_list FROM 'seed_data/my_list.csv' WITH (FORMAT csv, HEADER true)
\copy invoices FROM 'seed_data/invoices.csv' WITH (FORMAT csv, HEADER true)

ANALYZE;
