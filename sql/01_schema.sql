
-- Netflix Streaming Database
-- Phase 2: Schema Design

CREATE SCHEMA IF NOT EXISTS netflix;
SET search_path TO netflix;

-- 1. PLANS
CREATE TABLE plans (
    plan_id INTEGER PRIMARY KEY,
    plan_name VARCHAR(20) NOT NULL UNIQUE,
    monthly_price_inr NUMERIC(10,2) NOT NULL,
    max_streams SMALLINT NOT NULL,
    max_resolution VARCHAR(10) NOT NULL,
    has_ads BOOLEAN NOT NULL,

    CONSTRAINT chk_plan_name
        CHECK (plan_name IN ('MOBILE', 'BASIC', 'STANDARD', 'PREMIUM')),
    CONSTRAINT chk_plan_price CHECK (monthly_price_inr >= 0),
    CONSTRAINT chk_plan_streams CHECK (max_streams BETWEEN 1 AND 10),
    CONSTRAINT chk_plan_resolution
        CHECK (max_resolution IN ('480p', '720p', '1080p', '4K'))
);

-- 2. ACCOUNTS
CREATE TABLE accounts (
    account_id INTEGER PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20),
    country_code CHAR(2) NOT NULL,
    plan_id INTEGER NOT NULL,
    signup_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL,
    cancelled_on DATE,
    next_billing_date DATE,

    CONSTRAINT fk_accounts_plan
        FOREIGN KEY (plan_id) REFERENCES plans(plan_id),
    CONSTRAINT chk_account_status
        CHECK (status IN ('ACTIVE', 'CANCELLED', 'ON_HOLD')),
    CONSTRAINT chk_account_country
        CHECK (country_code IN ('IN', 'AE', 'SG')),
    CONSTRAINT chk_account_dates
        CHECK (cancelled_on IS NULL OR cancelled_on >= signup_date),
    CONSTRAINT chk_cancelled_date
        CHECK (status <> 'CANCELLED' OR cancelled_on IS NOT NULL)
);

-- 3. PROFILES
CREATE TABLE profiles (
    profile_id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL,
    profile_name VARCHAR(100) NOT NULL,
    is_kids BOOLEAN NOT NULL,
    maturity_limit VARCHAR(10) NOT NULL,
    language VARCHAR(30) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,

    CONSTRAINT fk_profiles_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id) ON DELETE CASCADE,
    CONSTRAINT chk_profile_maturity
        CHECK (maturity_limit IN ('U', 'UA7', 'UA13', 'UA16', 'A')),
    CONSTRAINT chk_profile_language
        CHECK (language IN ('Bengali', 'English', 'Hindi', 'Tamil', 'Telugu')),
    CONSTRAINT chk_kids_maturity
        CHECK (is_kids = FALSE OR maturity_limit IN ('U', 'UA7'))
);

-- 4. GENRES
CREATE TABLE genres (
    genre_id INTEGER PRIMARY KEY,
    genre_name VARCHAR(50) NOT NULL UNIQUE
);

-- 5. TITLES
CREATE TABLE titles (
    title_id INTEGER PRIMARY KEY,
    title_type VARCHAR(10) NOT NULL,
    name VARCHAR(255) NOT NULL,
    release_year SMALLINT NOT NULL,
    maturity_rating VARCHAR(10) NOT NULL,
    original_language VARCHAR(50) NOT NULL,
    runtime_min INTEGER,
    is_netflix_original BOOLEAN NOT NULL,
    added_on DATE NOT NULL,
    leaving_on DATE,

    CONSTRAINT chk_title_type
        CHECK (title_type IN ('MOVIE', 'SERIES')),
    CONSTRAINT chk_title_maturity
        CHECK (maturity_rating IN ('U', 'UA7', 'UA13', 'UA16', 'A')),
    CONSTRAINT chk_release_year
        CHECK (release_year BETWEEN 1888 AND 2100),
    CONSTRAINT chk_title_runtime
        CHECK (
            (title_type = 'MOVIE' AND runtime_min > 0)
            OR
            (title_type = 'SERIES' AND runtime_min IS NULL)
        ),
    CONSTRAINT chk_title_dates
        CHECK (leaving_on IS NULL OR leaving_on >= added_on),
    CONSTRAINT chk_original_never_leaves
        CHECK (is_netflix_original = FALSE OR leaving_on IS NULL)
);

-- 6. TITLE_GENRES
CREATE TABLE title_genres (
    title_id INTEGER NOT NULL,
    genre_id INTEGER NOT NULL,

    PRIMARY KEY (title_id, genre_id),

    CONSTRAINT fk_title_genres_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id) ON DELETE CASCADE,
    CONSTRAINT fk_title_genres_genre
        FOREIGN KEY (genre_id)
        REFERENCES genres(genre_id) ON DELETE CASCADE
);

-- 7. EPISODES
CREATE TABLE episodes (
    episode_id INTEGER PRIMARY KEY,
    title_id INTEGER NOT NULL,
    season_no SMALLINT NOT NULL,
    episode_no SMALLINT NOT NULL,
    episode_title VARCHAR(255) NOT NULL,
    runtime_min SMALLINT NOT NULL,
    release_date DATE NOT NULL,

    CONSTRAINT fk_episodes_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id) ON DELETE CASCADE,
    CONSTRAINT uq_episode_number
        UNIQUE (title_id, season_no, episode_no),
    CONSTRAINT chk_episode_season CHECK (season_no > 0),
    CONSTRAINT chk_episode_number CHECK (episode_no > 0),
    CONSTRAINT chk_episode_runtime CHECK (runtime_min > 0)
);

-- 8. VIEWING_ACTIVITY
CREATE TABLE viewing_activity (
    view_id BIGINT PRIMARY KEY,
    profile_id INTEGER NOT NULL,
    title_id INTEGER NOT NULL,
    episode_id INTEGER,
    started_at TIMESTAMPTZ NOT NULL,
    duration_watched_sec INTEGER NOT NULL,
    device_type VARCHAR(20) NOT NULL,
    completed BOOLEAN NOT NULL,

    CONSTRAINT fk_viewing_profile
        FOREIGN KEY (profile_id)
        REFERENCES profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT fk_viewing_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id),
    CONSTRAINT fk_viewing_episode
        FOREIGN KEY (episode_id)
        REFERENCES episodes(episode_id) ON DELETE SET NULL,
    CONSTRAINT chk_viewing_duration
        CHECK (duration_watched_sec >= 0),
    CONSTRAINT chk_viewing_device
        CHECK (device_type IN ('LAPTOP', 'MOBILE', 'TABLET', 'TV'))
);

-- 9. RATINGS
CREATE TABLE ratings (
    profile_id INTEGER NOT NULL,
    title_id INTEGER NOT NULL,
    rating VARCHAR(20) NOT NULL,
    rated_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (profile_id, title_id),

    CONSTRAINT fk_ratings_profile
        FOREIGN KEY (profile_id)
        REFERENCES profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT fk_ratings_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id) ON DELETE CASCADE,
    CONSTRAINT chk_rating_value
        CHECK (rating IN ('LOVE', 'THUMBS_UP', 'THUMBS_DOWN'))
);

-- 10. MY_LIST
CREATE TABLE my_list (
    profile_id INTEGER NOT NULL,
    title_id INTEGER NOT NULL,
    added_at TIMESTAMPTZ NOT NULL,

    PRIMARY KEY (profile_id, title_id),

    CONSTRAINT fk_my_list_profile
        FOREIGN KEY (profile_id)
        REFERENCES profiles(profile_id) ON DELETE CASCADE,
    CONSTRAINT fk_my_list_title
        FOREIGN KEY (title_id)
        REFERENCES titles(title_id) ON DELETE CASCADE
);

-- 11. INVOICES
CREATE TABLE invoices (
    invoice_id BIGINT PRIMARY KEY,
    account_id INTEGER NOT NULL,
    billing_period_start DATE NOT NULL,
    amount_inr NUMERIC(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL,
    paid_at TIMESTAMPTZ,

    CONSTRAINT fk_invoices_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),
    CONSTRAINT chk_invoice_amount CHECK (amount_inr >= 0),
    CONSTRAINT chk_invoice_status
        CHECK (status IN ('PAID', 'FAILED', 'REFUNDED')),
    CONSTRAINT chk_invoice_billing_day
        CHECK (EXTRACT(DAY FROM billing_period_start) = 1),
    CONSTRAINT chk_failed_invoice_payment
        CHECK (status <> 'FAILED' OR paid_at IS NULL)
);
