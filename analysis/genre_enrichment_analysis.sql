-- clean genres
create view clean_genres as
select genre_id, name
from genres
where ascii(left(name, 1)) between 65 and 122
and ascii(left(name, 1)) not between 91 and 96
and length(name) < 40
and length(name) > 2;

-- how many artists received genre tags
select
	count(*) as total_artists,
	count(mbid) as mb_match,
	round(count(mbid) * 100.0 / count(*), 1) as match_rate
from artists;

-- top genres
select
	g.name as genre,
	sum(p.play_count) as plays
from clean_genres g
join artist_genres ag on g.genre_id = ag.genre_id 
join artists a on ag.artist_id = a.artist_id 
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id 
group by g.name
order by plays desc
limit 20;

-- top artist per genre
with ranked as (
	select 
		g.name as genre, 
		a.name as artist,
		sum(p.play_count) as plays,
		dense_rank() over (partition by g.name order by sum(p.play_count) desc) as rank
	from clean_genres g
	join artist_genres ag on g.genre_id = ag.genre_id 
	join artists a on ag.artist_id = a.artist_id 
	join tracks t on a.artist_id = t.artist_id 
	join plays p on t.track_id = p.track_id
	group by g.name, a.name
)
select genre, artist, plays
from ranked
where rank <= 1
order by plays desc;

-- skip rate by genre
select g.name, sum(p.skip_count) as skips
from genres g
join artist_genres ag on g.genre_id = ag.genre_id 
join artists a on ag.artist_id = a.artist_id 
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id
group by g.name
order by skips desc
limit 50;

-- genre evolution
-- top genres per year
with ranked as (
	select 
		g.name as genre, 
	  	extract (year from p.played_at) as year,
		sum(p.play_count) as plays,
		rank() over (partition by extract (year from p.played_at) order by sum(p.play_count) desc) as rank
	from clean_genres g
	join artist_genres ag on g.genre_id = ag.genre_id 
	join artists a on ag.artist_id = a.artist_id 
	join tracks t on a.artist_id = t.artist_id 
	join plays p on t.track_id = p.track_id
	group by g.name, year
)
select genre, year, plays
from ranked
where rank <= 5
order by year desc, plays desc;