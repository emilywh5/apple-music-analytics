-- average energy by genre
select g.name as genre, f.energy, t.title,
	avg(f.energy) over (partition by g.name) as avg_energy
from genres g
join artist_genres ag on g.genre_id = ag.genre_id 
join artists a on ag.artist_id = a.artist_id
join tracks t on a.artist_id = t.artist_id 
join audio_features f on t.track_id = f.track_id 

-- rank songs by danceability within their genre
select t.title, a.name as artist, g.name as genre, f.danceability, 
	rank() over (partition by g.name order by f.danceability desc) as dance_rank,
	dense_rank() over (partition by g.name order by f.danceability desc) as dense_dance_rank
from tracks t 
join artists a on t.artist_id = a.artist_id 
join artist_genres ag on a.artist_id = ag.artist_id 
join genres g on ag.genre_id = g.genre_id 
join audio_features f on f.track_id = t.track_id 

-- order by release year within genre
select t.title, a.name as artist, g.name as genre, t.release_year,
	row_number() over (partition by g.name order by t.release_year desc) as release_row_no
from tracks t 
join artists a on t.artist_id = a.artist_id 
join artist_genres ag on a.artist_id = ag.artist_id 
join genres g on ag.genre_id = g.genre_id 
where t.release_year is not null

-- relative position of length of song within genre
select t.title, a.name as artist, g.name as genre, t.duration_ms as length,
	percent_rank() over (partition by g.name order by t.duration_ms desc) as length_percent_rank
from tracks t 
join artists a on t.artist_id = a.artist_id 
join artist_genres ag on a.artist_id = ag.artist_id 
join genres g on ag.genre_id = g.genre_id 
where t.duration_ms is not null