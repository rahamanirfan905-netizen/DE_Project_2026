-- CP3 indexes for the 30-query workload. Run after sql/02_load_data.sql.
SET search_path TO netflix;

-- R01: equality on profile and unfinished state; title then newest view for DISTINCT ON.
CREATE INDEX viewing_unfinished_profile_title_time_idx
    ON viewing_activity (profile_id, title_id, started_at DESC) WHERE NOT completed;

-- R03, R08, R18, R23: chronological range / newest-first support on the large event table.
CREATE INDEX viewing_started_at_desc_idx ON viewing_activity (started_at DESC);

-- R13: anti-join by non-null episode ID; excludes movie views.
CREATE INDEX viewing_episode_present_idx ON viewing_activity (episode_id) WHERE episode_id IS NOT NULL;

-- R10: exact lower(email) expression as written in the supplied query.
CREATE INDEX accounts_lower_email_idx ON accounts (lower(email));

-- R11, W05: failed invoices by billing period and account; partial status predicate.
CREATE INDEX invoices_failed_period_account_idx
    ON invoices (billing_period_start, account_id) WHERE status = 'FAILED';

-- R20: June additions range first, then title for grouping.
CREATE INDEX my_list_added_title_idx ON my_list (added_at, title_id);

-- R24: account equality then profile creation order.
CREATE INDEX profiles_account_created_idx ON profiles (account_id, created_at);

-- R25: reverse genre-to-title traversal not supported by the (title_id, genre_id) PK.
CREATE INDEX title_genres_genre_title_idx ON title_genres (genre_id, title_id);

ANALYZE;
