-- combine behavioral & genre data
create view track_features as
with play_stats as (
	select 
		t.track_id,
		t.title,
		a.name as artist,
		sum(p.play_count) as total_plays,
		sum(p.skip_count) as total_skips,
		round(sum(p.skip_count)::numeric /
			  nullif(sum(p.play_count), 0) * 100, 2) as skip_rate,
		round(avg(p.play_duration_ms), 1000) as avg_play_duration_sec,
		count(distinct(p.played_at)) as days_played,
		min(p.played_at) as first_played,
		max(p.played_at) as last_played,
		max(p.played_at) - min(p.played_at) as listening_period
	from tracks t
	join artists a on t.artist_id = a.artist_id
	join plays p on t.track_id = p.track_id
	group by t.track_id, t.title, a.name
),
genre_tags as (
	select 
		t.track_id,
		string_agg(g.name, ', ' order by g.name) as genres
	from tracks t
	join artists a on t.artist_id = a.artist_id
	join artist_genres ag on a.artist_id = ag.artist_id
	join clean_genres g on ag.genre_id = g.genre_id
	group by t.track_id
)
select 
	ps.*,
	gt.genres,
	case
		when ps.total_plays >= 20 then 'loved'
		when ps.total_plays >= 10 then 'liked'
		when ps.total_plays >= 3 then 'casual fan'
		else 'tried'
	end as affinity_tier,
	case
		when ps.skip_rate > 50 then 'high skip'
		when ps.skip_rate > 30 then 'moderate skip'
		when ps.skip_rate = 0 then 'never skipped'
		else 'low skip'
	end as skip_behavior,
	case
		when ps.days_played > 50 then 'long term'
		when ps.days_played > 20 then 'regular'
		when ps.days_played > 10 then 'occasional'
		else 'rare'
	end as listening_pattern
	from play_stats ps
	left join genre_tags gt on ps.track_id = gt.track_id;

-- view distribution of affinity and skip behavior
select affinity_tier, count(*) as track_count
from track_features
group by affinity_tier
order by track_count desc;

select skip_behavior, count(*) as track_count
from track_features
group by skip_behavior
order by track_count desc;