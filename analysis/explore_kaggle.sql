-- top twenty most common artists
select a."name", COUNT (t.track_id) as track_count
from artists a
join tracks t on a.artist_id = t.artist_id 
group by a."name" 
order by track_count desc
limit 20

-- top ten most common genres
select ag.genre_id, COUNT (t.track_id) as track_count
from artist_genres ag
join tracks t on ag.artist_id = t.artist_id 
group by ag.genre_id 
order by track_count desc
limit 10

-- average energy and danceability by genre
select g.name as genre,
	round(avg(f.danceability)::numeric, 2) as avg_danceability,
	round(avg(f.energy)::numeric, 2) as avg_energy
from genres g
join artist_genres ag on g.genre_id = ag.genre_id 
join artists a on ag.artist_id = a.artist_id
join tracks t on a.artist_id = t.artist_id 
join audio_features f on t.track_id = f.track_id 
group by g."name" 
order by avg_energy desc

-- track count by release decade
select  
    (release_year / 10) * 10 as decade,
    COUNT(*) as track_count
from tracks
where release_year is not null
group by decade
order by decade
