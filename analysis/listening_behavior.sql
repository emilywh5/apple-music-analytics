-- top 20 most played songs
select t.title, a.name, sum(p.play_count) as plays
from tracks t
join artists a on t.artist_id = a.artist_id 
join plays p on t.track_id = p.track_id 
group by t.title, a.name
order by plays desc
limit 20

-- top 200 most played songs of 2026
select t.title, a.name, sum(p.play_count) as plays
from tracks t
join artists a on t.artist_id = a.artist_id 
join plays p on t.track_id = p.track_id 
where EXTRACT(YEAR FROM p.played_at) = 2026
group by t.title, a.name
order by plays desc
limit 200

-- listening by month/year
select 
	extract(year from p.played_at) as listen_year,
	sum(p.play_duration_ms) / 60000 as yearly_listening_min
from plays p
group by extract(year from p.played_at)
order by listen_year

select 
	extract(month from p.played_at) as listen_month,
	sum(p.play_duration_ms) / 60000 as monthly_listening_min
from plays p
group by extract(month from p.played_at)
order by listen_month

-- top 20 artists
select a.name, sum(p.play_count) as plays
from artists a
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id
group by a.name
order by plays desc
limit 20

-- skip rate by artist
select a.name, sum(p.skip_count) as skips
from artists a
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id
group by a.name
order by skips desc
limit 50

-- skip to play ratio by artist among my most listened to
select 
	a.name, 
	sum(p.play_count) as plays,
	sum(p.skip_count) as skips,  
	(SUM(p.play_count) + 1) * 1.0 / (SUM(p.skip_count) + 1) AS ratio
from artists a
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id
group by a.name
having sum(p.play_count) > 1000
order by ratio desc
limit 50