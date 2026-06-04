import os
import time
import json
import requests
import pandas as pd
import sqlalchemy
from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()
engine = create_engine(f"postgresql://postgres:{os.getenv('DB_PASSWORD')}@localhost:5432/musicdb")

HEADERS = {
    "User-Agent": "apple-music-analytics/1.0 (ecw31415@gmail.com)"
}

CHECKPOINT_FILE = "data/musicbrainz_checkpoint.json"

def search_artist(artist_name):
    url = "https://musicbrainz.org/ws/2/artist"
    params = {
        "query": f'artist:"{artist_name}"',
        "fmt": "json",
        "limit": 1
    }
    try:
        response = requests.get(url, params=params, headers=HEADERS)
        response.raise_for_status()
        data = response.json()
        if data['artists']:
            artist = data['artists'][0]
            mbid = artist.get('id')
            tags = [t['name'] for t in artist.get('tags', [])] if artist.get('tags') else []
            country = artist.get('country', None)
            return mbid, tags, country
        return None, [], None
    except Exception as e:
        print(f"error fetching {artist_name}: {e}")
        return None, [], None

# load checkpoint if exists
if os.path.exists(CHECKPOINT_FILE):
    with open(CHECKPOINT_FILE, 'r') as f:
        checkpoint = json.load(f)
    print(f"resuming from checkpoint: {len(checkpoint)} artists already processed")
else:
    checkpoint = {}

# load all artists from database
artists = pd.read_sql("SELECT artist_id, name FROM artists", engine)
print(f"total artists to enrich: {len(artists)}")

# process each artist
for _, row in artists.iterrows():
    artist_id = str(row['artist_id'])
    artist_name = row['name']

    # skip if already processed
    if artist_id in checkpoint:
        continue

    print(f"fetching: {artist_name}")
    mbid, tags, country = search_artist(artist_name)

    checkpoint[artist_id] = {
        'mbid': mbid,
        'tags': tags,
        'country': country
    }

    # save checkpoint every 10 artists
    if len(checkpoint) % 10 == 0:
        with open(CHECKPOINT_FILE, 'w') as f:
            json.dump(checkpoint, f)
        print(f"checkpoint saved: {len(checkpoint)} artists processed")

    time.sleep(1)

# final checkpoint save
with open(CHECKPOINT_FILE, 'w') as f:
    json.dump(checkpoint, f)
print("all artists fetched, saving to database...")

# update database with results
with engine.begin() as conn:
    for artist_id, data in checkpoint.items():
        conn.execute(sqlalchemy.text("""
            UPDATE artists 
            SET mbid = :mbid, country = :country
            WHERE artist_id = :artist_id
        """), {
            'mbid': data['mbid'],
            'country': data['country'],
            'artist_id': int(artist_id)
        })
print("artists updated in database")

# load genres
print("loading genres...")
all_tags = set()
for data in checkpoint.values():
    for tag in data['tags']:
        all_tags.add(tag)

genres_df = pd.DataFrame(list(all_tags), columns=['name'])
genres_df['genre_id'] = genres_df.index + 1
genres_df.to_sql('genres', engine, if_exists='append', index=False)
print(f"genres loaded: {len(genres_df)} rows")

# load artist_genres
print("loading artist genres...")
artist_genre_rows = []
genre_lookup = {row['name']: row['genre_id'] 
                for _, row in genres_df.iterrows()}

for artist_id, data in checkpoint.items():
    for tag in data['tags']:
        if tag in genre_lookup:
            artist_genre_rows.append({
                'artist_id': int(artist_id),
                'genre_id': genre_lookup[tag]
            })

if artist_genre_rows:
    ag_df = pd.DataFrame(artist_genre_rows).drop_duplicates()
    ag_df.to_sql('artist_genres', engine, if_exists='append', index=False)
    print(f"artist_genres loaded: {len(ag_df)} rows")

print("enrichment complete!")