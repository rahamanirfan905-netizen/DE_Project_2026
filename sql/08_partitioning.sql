-- ============================================================
-- CP4: Monthly Range Partitioning for Viewing Activity
-- Database: PostgreSQL
-- Original table: netflix.viewing_activity (kept unchanged)
-- Experimental partitioned table: netflix.viewing_activity_partitioned
-- Partition key: started_at
-- ============================================================

CREATE TABLE IF NOT EXISTS netflix.viewing_activity_partitioned (
    view_id BIGINT NOT NULL,
    profile_id INTEGER NOT NULL,
    title_id INTEGER NOT NULL,
    episode_id INTEGER,
    started_at TIMESTAMPTZ NOT NULL,
    duration_watched_sec INTEGER NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    completed BOOLEAN NOT NULL,

    CONSTRAINT viewing_activity_partitioned_pkey
        PRIMARY KEY (view_id, started_at),

    CONSTRAINT chk_partitioned_device
        CHECK (device_type IN ('LAPTOP', 'MOBILE', 'TABLET', 'TV')),

    CONSTRAINT chk_partitioned_duration
        CHECK (duration_watched_sec >= 0),

    CONSTRAINT fk_partitioned_episode
        FOREIGN KEY (episode_id)
        REFERENCES netflix.episodes(episode_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_partitioned_profile
        FOREIGN KEY (profile_id)
        REFERENCES netflix.profiles(profile_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_partitioned_title
        FOREIGN KEY (title_id)
        REFERENCES netflix.titles(title_id)
)
PARTITION BY RANGE (started_at);

-- Create one monthly partition from January 2025 through July 2026.
-- The upper boundary is August 1, 2026.
DO $$
DECLARE
    month_start DATE := DATE '2025-01-01';
    month_end DATE;
    partition_name TEXT;
BEGIN
    WHILE month_start < DATE '2026-08-01' LOOP
        month_end := (month_start + INTERVAL '1 month')::DATE;

        partition_name := 'viewing_activity_p_' ||
                         TO_CHAR(month_start, 'YYYY_MM');

        EXECUTE FORMAT(
            'CREATE TABLE IF NOT EXISTS netflix.%I
             PARTITION OF netflix.viewing_activity_partitioned
             FOR VALUES FROM (%L) TO (%L)',
            partition_name,
            month_start,
            month_end
        );

        month_start := month_end;
    END LOOP;
END $$;

-- Reload data into the partitioned table.
-- This affects only the experimental partitioned table.
TRUNCATE TABLE netflix.viewing_activity_partitioned;

INSERT INTO netflix.viewing_activity_partitioned
SELECT *
FROM netflix.viewing_activity;

-- Update statistics for the query planner.
ANALYZE netflix.viewing_activity_partitioned;

-- Verify the copied row count.
SELECT
    (SELECT COUNT(*) FROM netflix.viewing_activity)
        AS original_rows,
    (SELECT COUNT(*) FROM netflix.viewing_activity_partitioned)
        AS partitioned_rows;
