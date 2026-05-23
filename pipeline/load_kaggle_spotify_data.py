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

df = pd.read_csv("data/spotify_songs.csv")

# identify columns with null values
# print(df.shape)
# print(df.head())
# print(df.columns.tolist())
# print(df.isnull().sum())

# drop null rows
df = df.dropna(subset=['track_name', 'track_artist', 'track_album_name'])
# print(df.shape) # expecting 32828

# --- artists table ---
artists = df[['track_artist']].drop_duplicates().reset_index(drop=True)
artists.columns = ['name']
artists['artist_id'] = artists.index + 1
artists.to_sql('artists', engine, if_exists='append', index=False)
print(f"artists loaded: {len(artists)} rows")

# --- tracks table ---
tracks = df[['track_name', 'track_artist', 'track_album_name', 'track_album_release_date',
             'duration_ms']].drop_duplicates(subset=['track_name', 'track_artist']).copy()
tracks = tracks.merge(artists, left_on='track_artist', right_on='name')
tracks = tracks[['track_name', 'artist_id', 'track_album_name', 'track_album_release_date',
                 'duration_ms']]
tracks.columns = ['title', 'artist_id', 'album', 'release_year', 'duration_ms']
tracks['track_id'] = tracks.index + 1
tracks['release_year'] = pd.to_datetime(tracks['release_year'], errors='coerce').dt.year
tracks.to_sql('tracks', engine, if_exists='append', index=False)
print(f"tracks loaded: {len(tracks)} rows")

# --- genres table ---
genres = pd.concat([
    df['playlist_genre'], 
    df['playlist_subgenre']
    ]).drop_duplicates().reset_index(drop=True).to_frame()
genres.columns = ['name']
genres['genre_id'] = genres.index + 1
genres.to_sql('genres', engine, if_exists='append', index=False)
print(f"genres loaded: {len(genres)} rows")

# --- artist_genres table ---
artist_genres = df[['track_artist', 'playlist_genre']].drop_duplicates()
artist_genres = artist_genres.merge(artists, left_on='track_artist', right_on='name')
artist_genres = artist_genres.merge(genres, left_on='playlist_genre', right_on='name')
artist_genres = artist_genres[['artist_id', 'genre_id']].drop_duplicates()
artist_genres.to_sql('artist_genres', engine, if_exists='append', index=False)
print(f"artist_genres loaded: {len(artist_genres)} rows")

# --- audio_features table ---
features = df[
    ['track_name', 'track_artist', 'danceability', 'energy', 'speechiness',
     'acousticness', 'valence', 'tempo']
    ].drop_duplicates(subset=['track_name', 'track_artist']).copy()
features = features.merge(
    tracks[['title', 'track_id']].drop_duplicates(subset=['title']),
    left_on='track_name',
    right_on='title',
    how='inner'
).drop_duplicates(subset=['track_id'])
features = features[['track_id', 'danceability', 'energy', 'speechiness', 
                     'acousticness', 'valence', 'tempo']]
features.to_sql('audio_features', engine, if_exists='append', index=False)
print(f"audio features loaded: {len(features)} rows")