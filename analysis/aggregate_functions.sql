-- average audio features by genre
select g.name as genre,
	round(avg(f.danceability)::numeric, 2) as avg_danceability,
	round(avg(f.energy)::numeric, 2) as avg_energy,
	round(avg(f.tempo)::numeric, 2) as avg_tempo,
	round(avg(f.valence)::numeric, 2) as avg_valence,
	round(avg(f.acousticness)::numeric, 2) as avg_acousticness,
	round(avg(f.speechiness)::numeric, 2) as avg_speechiness
from genres g
join artist_genres ag on g.genre_id = ag.genre_id
join artists a on ag.artist_id = a.artist_id
join tracks t on a.artist_id = t.artist_id
join audio_features f on t.track_id = f.track_id
group by g.name
order by avg_danceability desc

-- pop songs with valence over 0.95
select 
	t.title, 
	a."name" as artist, 
	f.valence, 
	g."name" as genre 
from tracks t
join artists a on t.artist_id = a.artist_id 
join artist_genres ag on a.artist_id = ag.artist_id 
join genres g on ag.genre_id = g.genre_id 
join audio_features f on t.track_id = f.track_id 
where g."name" = 'pop'
	and f.valence > 0.95
order by f.valence desc
limit 25

-- tracks per artist
select a."name" as artist, count(t.track_id) as track_count
from artists a
join tracks t on a.artist_id = t.artist_id 
group by a."name"
order by track_count desc

-- average valence per artist
select 
	a."name" as artist,
	round(avg(f.valence)::numeric, 2) as avg_valence
from artists a
join tracks t on a.artist_id = t.track_id 
join audio_features f on t.track_id = f.track_id 
group by a."name"
order by avg_valence desc