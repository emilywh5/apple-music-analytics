CREATE TABLE artists (
    artist_id     SERIAL PRIMARY KEY,
    name          TEXT NOT NULL,
    mbid          TEXT,
    country       TEXT,
    lastfm_listeners  INT,
    lastfm_playcount  INT
);

CREATE TABLE tracks (
    track_id      SERIAL PRIMARY KEY,
    title         TEXT NOT NULL,
    artist_id     INT REFERENCES artists(artist_id),
    album         TEXT,
    release_year  INT,
    duration_ms   INT,
    mbid          TEXT
);

CREATE TABLE plays (
    play_id           SERIAL PRIMARY KEY,
    track_id          INT REFERENCES tracks(track_id),
    played_at         TIMESTAMP,
    play_duration_ms  INT,
    skipped           BOOLEAN
);

CREATE TABLE genres (
    genre_id      SERIAL PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE
);

CREATE TABLE artist_genres (
    artist_id     INT REFERENCES artists(artist_id),
    genre_id      INT REFERENCES genres(genre_id),
    PRIMARY KEY (artist_id, genre_id)
);

CREATE TABLE audio_features (
    track_id      INT REFERENCES tracks(track_id) PRIMARY KEY,
    tempo         NUMERIC,
    energy        NUMERIC,
    valence       NUMERIC,
    acousticness  NUMERIC,
    speechiness   NUMERIC,
    danceability  NUMERIC
);

CREATE TABLE similar_artists (
    artist_id         INT REFERENCES artists(artist_id),
    similar_artist_id INT REFERENCES artists(artist_id),
    similarity_score  NUMERIC,
    PRIMARY KEY (artist_id, similar_artist_id)
);