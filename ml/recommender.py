import os
import pandas as pd
import sqlalchemy
import numpy as np
import umap
import hdbscan
import matplotlib.pyplot as plt
import seaborn as sns
import plotly.express as px
from dotenv import load_dotenv
from sqlalchemy import create_engine
from sklearn.metrics.pairwise import euclidean_distances

FEATURE_COLS = [
    "z_log_total_plays",
    "z_log_total_skips",
    "z_log_days_played",
    "z_log_listening_period",
    "z_log_skip_adj_pop",
    "z_session_intensity",
    "z_recency_score",
    "z_loyalty_index",
    "z_genre_diversity",
    "affinity_loved",
    "affinity_liked",
    "affinity_casual",
    "affinity_tried",
    "skip_high",
    "skip_moderate",
    "skip_low",
    "skip_never",
    "pattern_long_term",
    "pattern_regular",
    "pattern_occasional",
    "pattern_rare"
]

# Cluster Inspection & Labelling

def label_cluster(df, cluster_id):
    cluster_df = df[df["cluster"] == cluster_id]

    # Top genres
    top_genres = (
        cluster_df["genres"]
        .dropna()
        .str.split(",")
        .explode()
        .str.strip()
        .value_counts()
        .head(4)
        .index.tolist()
    )

    generic = ["pop"]
    subgenres = [g for g in top_genres if g.lower() not in generic]
    has_generic = any(g.lower() in generic for g in top_genres)

    final_genres = subgenres[:2]
    if has_generic:
        final_genres.append("pop")

    # Top artists
    top_artists = (
        cluster_df["artist_name"]
        .dropna()
        .value_counts()
        .head(2)
        .index.tolist()
    )

    parts = []
    if final_genres:
        parts.append("/".join(final_genres))

    if top_artists:
        parts.append(f"({', '.join(top_artists)})")

    if not parts:
        return f"Cluster {cluster_id}"

    return " ".join(parts)

# Visualization

def plot_clusters_interactive(df):
    df_plot = df.sort_values(by="cluster")

    fig = px.scatter(
        df_plot,
        x="umap_x",
        y="umap_y",
        color="cluster_label",
        hover_data={
            "track_name": True,
            "artist_name": True,
            "genres": True,
            "cluster_label": True,
            "umap_x": False,
            "umap_y": False
        },
        width=1200,
        height=900
    )

    fig.update_traces(marker=dict(size=6, opacity=0.8))
    fig.update_layout(
        title="UMAP Embedding with Interactive Cluster Labels",
        legend_title="Cluster",
        legend=dict(
            itemsizing="constant",
            font=dict(size=10),
            orientation="v"
        )
    )

    fig.show()

# Recommender

def get_recommendations(df, track_id, top_n=5, method='feature'):
    """
    method: 'feature' uses original attributes
    method: 'spatial' uses UMAP coordinates
    """
    if method == 'feature':
        data_matrix = df[FEATURE_COLS].values
    else:
        data_matrix = df[["umap_x", "umap_y"]].values
   
    idx = df.index[df["track_id"] == track_id].tolist()
    if not idx: return None
    target_idx = idx[0]
    
    distances = euclidean_distances(data_matrix, [data_matrix[target_idx]]).flatten()
    
    df_rec = df.copy()
    df_rec["distance"] = distances
    return df_rec.sort_values("distance").iloc[1:top_n+1]

def plot_recommendations_interactive(df, track_id, top_n=5):
    recs = get_recommendations(df, track_id, top_n=top_n, method='spatial')
    target = df[df["track_id"] == track_id]
    
    fig = px.scatter(df, x="umap_x", y="umap_y", color="cluster_label", opacity=0.3)
    
    fig.add_scatter(x=recs["umap_x"], y=recs["umap_y"], mode='markers', 
                    name='Recommended', marker=dict(size=12, color='red'))
    
    fig.add_scatter(x=target["umap_x"], y=target["umap_y"], mode='markers', 
                    name='Target', marker=dict(size=15, color='blue', symbol='star'))
    
    fig.show()

def recommend_and_visualize_random(df, top_n=5, method='feature'):
    """
    Selects a random track from the dataset, finds recommendations,
    prints the results to the console, and displays them on an interactive map.
    """
    # Pick a random track that isn't classified as noise
    valid_tracks = df[df["cluster"] != -1]
    if valid_tracks.empty:
        valid_tracks = df
        
    random_track = valid_tracks.sample(n=1).iloc[0]
    track_id = random_track["track_id"]
    
    # Generate recommendations
    if method == 'feature':
        data_matrix = df[FEATURE_COLS].values
    else:
        data_matrix = df[["umap_x", "umap_y"]].values
        
    idx = df.index[df["track_id"] == track_id].tolist()[0]
    target_coords = data_matrix[idx].reshape(1, -1)
    
    distances = euclidean_distances(data_matrix, target_coords).flatten()
    
    df_result = df.copy()
    df_result["distance"] = distances
    
    target_df = df_result.loc[[idx]]
    recs_df = df_result[df_result["track_id"] != track_id].sort_values("distance").head(top_n)
    background_df = df_result[~df_result["track_id"].isin([track_id] + recs_df["track_id"].tolist())]
    
    print("\n" + "="*50)
    print(f"TARGET TRACK: '{random_track['track_name']}' by {random_track['artist_name']}")
    print(f"   Cluster: {random_track['cluster_label']}")
    print("="*50)
    print(f"TOP {top_n} RECOMMENDATIONS:")
    for i, (_, row) in enumerate(recs_df.iterrows(), 1):
        print(f" {i}. '{row['track_name']}' by {row['artist_name']}")
        print(f"    ↳ Cluster: {row['cluster_label']} | Distance: {row['distance']:.4f}")
    print("="*50 + "\n")
    
    # Build the Interactive Plotly Visualization
    import plotly.graph_objects as go
    
    fig = go.Figure()
    
    # Regular background map
    fig.add_trace(go.Scatter(
        x=background_df["umap_x"],
        y=background_df["umap_y"],
        mode='markers',
        name='Your Library',
        marker=dict(size=5, color=background_df["cluster"], colorscale='Viridis', opacity=0.25),
        text=background_df["track_name"] + " by " + background_df["artist_name"],
        hoverinfo='text'
    ))
    
    # Recommendations (Bold Red Diamonds)
    fig.add_trace(go.Scatter(
        x=recs_df["umap_x"],
        y=recs_df["umap_y"],
        mode='markers',
        name='Recommendations',
        marker=dict(size=12, color='crimson', symbol='diamond', line=dict(width=2, color='white')),
        text=recs_df["track_name"] + " by " + recs_df["artist_name"] + "<br>Cluster: " + recs_df["cluster_label"],
        hoverinfo='text'
    ))
    
    # Target Track (Large Blue Star)
    fig.add_trace(go.Scatter(
        x=target_df["umap_x"],
        y=target_df["umap_y"],
        mode='markers',
        name='Target Track',
        marker=dict(size=18, color='dodgerblue', symbol='star', line=dict(width=2, color='white')),
        text=target_df["track_name"] + " by " + target_df["artist_name"],
        hoverinfo='text'
    ))
    
    fig.update_layout(
        title=f"Recommendations for: {random_track['track_name']} ({random_track['artist_name']})",
        xaxis_title="UMAP X",
        yaxis_title="UMAP Y",
        width=1200,
        height=800,
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1)
    )
    
    fig.show()

# Load & Process Data

load_dotenv()
engine = create_engine(f"postgresql://postgres:{os.getenv('DB_PASSWORD')}@localhost:5432/musicdb")

df = pd.read_sql("""
    SELECT 
        f.*, 
        t.title as track_name,
        a.name as artist_name,
        STRING_AGG(g.name, ', ') as genres
    FROM track_features_clean f
    JOIN tracks t ON f.track_id = t.track_id
    JOIN artists a ON t.artist_id = a.artist_id
    LEFT JOIN artist_genres ag ON a.artist_id = ag.artist_id
    LEFT JOIN genres g ON ag.genre_id = g.genre_id
    GROUP BY f.track_id, t.title, a.name, f.z_log_total_plays, f.z_log_total_skips, 
             f.z_log_days_played, f.z_log_listening_period, f.z_log_skip_adj_pop, 
             f.z_session_intensity, f.z_recency_score, f.z_loyalty_index, 
             f.z_genre_diversity, f.affinity_loved, f.affinity_liked, 
             f.affinity_casual, f.affinity_tried, f.skip_high, f.skip_moderate, 
             f.skip_low, f.skip_never, f.pattern_long_term, f.pattern_regular, 
             f.pattern_occasional, f.pattern_rare
""", engine)
df = df.dropna(subset=FEATURE_COLS)

ml_matrix = df[FEATURE_COLS].values

# UMAP
u = umap.UMAP(
    n_neighbors=30,
    min_dist=0.1,
    metric="cosine",
    random_state=42
)
coords_umap = u.fit_transform(ml_matrix)
df["umap_x"] = coords_umap[:, 0]
df["umap_y"] = coords_umap[:, 1]

# HDBSCAN
clusterer = hdbscan.HDBSCAN(
    min_cluster_size=20,
    metric='euclidean'
)
df["cluster"] = clusterer.fit_predict(coords_umap)

# Generate Cluster Labels

cluster_labels = {}
for c in sorted(df["cluster"].unique()):
    if c == -1:
        cluster_labels[c] = "Noise / Unclassified"
    else:
        cluster_labels[c] = label_cluster(df, c)

df["cluster_label"] = df["cluster"].map(cluster_labels)

# Get Recommendations

sample_track_id = df.iloc[0]["track_id"]
recs = get_recommendations(df, sample_track_id, top_n=5, method='feature')

# Final Plot

# Option 1: See entire interactive map
plot_clusters_interactive(df)

# Option 2: See recommendations for a random track
# recommend_and_visualize_random(df, top_n=10, method='feature')

# Export the enriched data for Tableau
df.to_csv("apple_music_taste_clusters.csv", index=False)
print("Data exported successfully for Tableau")