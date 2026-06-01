import os
import pandas as pd
import sqlalchemy
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()
print(f"password being used: {os.getenv('DB_PASSWORD')}")

engine = create_engine(f"postgresql://postgres:{os.getenv('DB_PASSWORD')}@localhost:5432/musicdb")

# clear all tables before loading
with engine.begin() as conn:
    conn.execute(sqlalchemy.text(
        "TRUNCATE TABLE audio_features, artist_genres, genres, tracks, artists RESTART IDENTITY CASCADE"
    ))
print("tables cleared")

df = pd.read_csv("data/apple_music_activity/Apple Music - Play History Daily Tracks.csv")

df = df.dropna(subset=['Track Description'])

df[['artist_name', 'track_name']] = df['Track Description'].str.split(' - ', n=1, expand=True)
df = df.rename(columns={
    'Date Played': 'played_at',
    'Play Duration Milliseconds': 'play_duration_ms',
    'Play Count': 'play_count',
    'Skip Count': 'skip_count'
})

# --- artists table ---
artists = df[['artist_name']].drop_duplicates().reset_index(drop=True)

artists.columns = ['name']
artists['artist_id'] = artists.index + 1

artists.to_sql('artists', engine, if_exists='append', index=False)
print(f"artists loaded: {len(artists)} rows")

# --- tracks table ---
tracks = df[['track_name', 'artist_name']].drop_duplicates(
    subset=['track_name', 'artist_name']).copy()

tracks = tracks.merge(artists, left_on='artist_name', right_on='name')

tracks = tracks[['track_name', 'artist_id']]
tracks.columns = ['title', 'artist_id']
tracks['track_id'] = tracks.index + 1

tracks = tracks.dropna(subset=['title', 'artist_id'])

tracks.to_sql('tracks', engine, if_exists='append', index=False)
print(f"tracks loaded: {len(tracks)} rows")

# --- plays table ---
plays = df[['played_at', 'play_duration_ms', 'track_name', 'artist_name', 
            'play_count', 'skip_count']].copy()

plays = plays.merge(
    tracks[['title', 'artist_id', 'track_id']].merge(
        artists[['name', 'artist_id']], on='artist_id'
    ),
    left_on=['track_name', 'artist_name'],
    right_on=['title', 'name'],
    how='inner'
)

plays = plays[['track_id', 'played_at', 'play_duration_ms', 'play_count', 'skip_count']]
plays['played_at'] = pd.to_datetime(plays['played_at'], format='%Y%m%d')

plays = plays.drop_duplicates(subset=['track_id', 'played_at'])

plays.to_sql('plays', engine, if_exists='append', index=False)
print(f"plays loaded: {len(plays)} rows")