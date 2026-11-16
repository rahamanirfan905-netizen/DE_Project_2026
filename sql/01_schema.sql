-- CP1 schema.  Run against an empty PostgreSQL 15+ database.
CREATE SCHEMA netflix;
SET search_path TO netflix;

CREATE TABLE plans (
    plan_id            integer PRIMARY KEY CHECK (plan_id > 0),
    plan_name          text NOT NULL UNIQUE CHECK (plan_name IN ('MOBILE', 'BASIC', 'STANDARD', 'PREMIUM')),
    monthly_price_inr  numeric(8,2) NOT NULL CHECK (monthly_price_inr > 0),
    max_streams        smallint NOT NULL CHECK (max_streams BETWEEN 1 AND 5),
    max_resolution     text NOT NULL CHECK (max_resolution IN ('480p', '720p', '1080p', '4K')),
    has_ads            boolean NOT NULL
);

CREATE TABLE accounts (
    account_id         integer PRIMARY KEY CHECK (account_id > 0),
    email              text NOT NULL UNIQUE CHECK (email = lower(email)),
    phone              text UNIQUE CHECK (phone IS NULL OR phone ~ '^[0-9]{10,15}$'),
    country_code       char(2) NOT NULL CHECK (country_code IN ('IN', 'AE', 'SG')),
    plan_id            integer NOT NULL REFERENCES plans(plan_id) ON DELETE RESTRICT,
    signup_date        date NOT NULL,
    status             text NOT NULL CHECK (status IN ('ACTIVE', 'CANCELLED', 'ON_HOLD')),
    cancelled_on       date,
    next_billing_date  date,
    CONSTRAINT accounts_status_dates_ck CHECK (
        (status = 'CANCELLED' AND cancelled_on IS NOT NULL AND next_billing_date IS NULL)
        OR (status IN ('ACTIVE', 'ON_HOLD') AND cancelled_on IS NULL AND next_billing_date IS NOT NULL)
    ),
    CONSTRAINT accounts_cancel_after_signup_ck CHECK (cancelled_on IS NULL OR cancelled_on >= signup_date)
);

CREATE TABLE profiles (
    profile_id         integer PRIMARY KEY CHECK (profile_id > 0),
    account_id         integer NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
    profile_name       text NOT NULL CHECK (btrim(profile_name) <> ''),
    is_kids            boolean NOT NULL,
    maturity_limit     text NOT NULL CHECK (maturity_limit IN ('U', 'UA7', 'UA13', 'UA16', 'A')),
    language           text NOT NULL CHECK (language IN ('English', 'Hindi', 'Bengali', 'Tamil', 'Telugu')),
    created_at         timestamptz NOT NULL,
    CONSTRAINT profiles_kids_maturity_ck CHECK (NOT is_kids OR maturity_limit IN ('U', 'UA7')),
    CONSTRAINT profiles_account_name_uq UNIQUE (account_id, profile_name)
);

CREATE TABLE genres (
    genre_id           integer PRIMARY KEY CHECK (genre_id > 0),
    genre_name         text NOT NULL UNIQUE CHECK (btrim(genre_name) <> '')
);

CREATE TABLE titles (
    title_id           integer PRIMARY KEY CHECK (title_id > 0),
    title_type         text NOT NULL CHECK (title_type IN ('MOVIE', 'SERIES')),
    name               text NOT NULL CHECK (btrim(name) <> ''),
    release_year       smallint NOT NULL CHECK (release_year BETWEEN 1888 AND 2100),
    maturity_rating    text NOT NULL CHECK (maturity_rating IN ('U', 'UA7', 'UA13', 'UA16', 'A')),
    original_language  text NOT NULL CHECK (original_language IN ('English', 'Hindi', 'Tamil', 'Telugu', 'Japanese', 'Korean', 'Spanish')),
    runtime_min        smallint,
    is_netflix_original boolean NOT NULL,
    added_on           date NOT NULL,
    leaving_on         date,
    CONSTRAINT titles_type_runtime_ck CHECK (
        (title_type = 'MOVIE' AND runtime_min BETWEEN 1 AND 600)
        OR (title_type = 'SERIES' AND runtime_min IS NULL)
    ),
    CONSTRAINT titles_original_leaving_ck CHECK (NOT is_netflix_original OR leaving_on IS NULL),
    CONSTRAINT titles_leaving_after_added_ck CHECK (leaving_on IS NULL OR leaving_on > added_on)
);

CREATE TABLE title_genres (
    title_id           integer NOT NULL REFERENCES titles(title_id) ON DELETE CASCADE,
    genre_id           integer NOT NULL REFERENCES genres(genre_id) ON DELETE RESTRICT,
    PRIMARY KEY (title_id, genre_id)
);

CREATE TABLE episodes (
    episode_id         integer PRIMARY KEY CHECK (episode_id > 0),
    title_id           integer NOT NULL,
    season_no          smallint NOT NULL CHECK (season_no > 0),
    episode_no         smallint NOT NULL CHECK (episode_no > 0),
    episode_title      text NOT NULL CHECK (btrim(episode_title) <> ''),
    runtime_min        smallint NOT NULL CHECK (runtime_min BETWEEN 1 AND 600),
    release_date       date NOT NULL,
    CONSTRAINT episodes_title_fk FOREIGN KEY (title_id) REFERENCES titles(title_id) ON DELETE RESTRICT,
    CONSTRAINT episodes_title_season_episode_uq UNIQUE (title_id, season_no, episode_no),
    CONSTRAINT episodes_id_title_uq UNIQUE (episode_id, title_id)
);

CREATE TABLE viewing_activity (
    view_id                bigint PRIMARY KEY CHECK (view_id > 0),
    profile_id             integer NOT NULL REFERENCES profiles(profile_id) ON DELETE RESTRICT,
    title_id               integer NOT NULL REFERENCES titles(title_id) ON DELETE RESTRICT,
    episode_id             integer,
    started_at             timestamptz NOT NULL,
    duration_watched_sec   integer NOT NULL CHECK (duration_watched_sec > 0),
    device_type            text NOT NULL CHECK (device_type IN ('TV', 'MOBILE', 'TABLET', 'LAPTOP')),
    completed              boolean NOT NULL,
    CONSTRAINT viewing_activity_episode_title_fk
        FOREIGN KEY (episode_id, title_id) REFERENCES episodes(episode_id, title_id) ON DELETE RESTRICT
);

CREATE TABLE ratings (
    profile_id          integer NOT NULL REFERENCES profiles(profile_id) ON DELETE CASCADE,
    title_id            integer NOT NULL REFERENCES titles(title_id) ON DELETE RESTRICT,
    rating              text NOT NULL CHECK (rating IN ('THUMBS_DOWN', 'THUMBS_UP', 'LOVE')),
    rated_at            timestamptz NOT NULL,
    PRIMARY KEY (profile_id, title_id)
);

CREATE TABLE my_list (
    profile_id          integer NOT NULL REFERENCES profiles(profile_id) ON DELETE CASCADE,
    title_id            integer NOT NULL REFERENCES titles(title_id) ON DELETE RESTRICT,
    added_at            timestamptz NOT NULL,
    PRIMARY KEY (profile_id, title_id)
);

CREATE TABLE invoices (
    invoice_id             bigint PRIMARY KEY CHECK (invoice_id > 0),
    account_id             integer NOT NULL REFERENCES accounts(account_id) ON DELETE RESTRICT,
    billing_period_start   date NOT NULL CHECK (EXTRACT(DAY FROM billing_period_start) = 1),
    amount_inr             numeric(8,2) NOT NULL CHECK (amount_inr > 0),
    status                 text NOT NULL CHECK (status IN ('PAID', 'FAILED', 'REFUNDED')),
    paid_at                timestamptz,
    CONSTRAINT invoices_account_period_uq UNIQUE (account_id, billing_period_start),
    CONSTRAINT invoices_payment_status_ck CHECK (
        (status IN ('PAID', 'REFUNDED') AND paid_at IS NOT NULL)
        OR (status = 'FAILED' AND paid_at IS NULL)
    ),
    CONSTRAINT invoices_paid_after_period_ck CHECK (paid_at IS NULL OR paid_at::date >= billing_period_start)
);
