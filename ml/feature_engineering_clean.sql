-- add engineered features
create view track_features_engineered as
with base as (
	select
		tf.track_id,
		tf.title,
		tf.artist,
		tf.total_plays,
		tf.total_skips,
		tf.skip_rate,
		tf.days_played,
		tf.first_played,
		tf.last_played,
		tf.listening_period,
		tf.avg_play_duration_sec,
		tf.genres,
		-- recency (days)
		(current_date - tf.last_played::date) AS days_since_last_play,
		-- number of genres
		array_length(string_to_array(tf.genres, ', '), 1) as genre_count
	from track_features tf
)

select
	b.*,
	-- session intensity
	case
		when b.days_played = 0 then 0
		else b.total_plays::numeric / b.days_played
	end as session_intensity,
	-- recency score
	exp(-b.days_since_last_play / 30.0) as recency_score,
	-- loyalty index
	case
		when b.listening_period = interval '0 days' then 0
		else (b.days_played::numeric - extract(day from b.listening_period)::numeric) * (1 - b.skip_rate / 100.0)
	end as loyalty_index,
	-- skip-adjusted popularity
	b.total_plays * (1 - b.skip_rate / 100.0) as skip_adjusted_popularity,
	-- genre diversity
	coalesce(b.genre_count, 1) as genre_diversity,
	-- one hot encode affinity, skip behavior, and listening pattern
	-- affinity
	case when b.total_plays >= 20 then 1 else 0 end as affinity_loved,
	case when b.total_plays between 10 and 19 then 1 else 0 end as affinity_liked,
	case when b.total_plays between 3 and 9 then 1 else 0 end as affinity_casual,
	case when b.total_plays < 3 then 1 else 0 end as affinity_tried,
	-- skip behavior
	case when b.skip_rate > 50 then 1 else 0 end as skip_high,
	case when b.skip_rate between 31 and 50 then 1 else 0 end as skip_moderate,
	case when b.skip_rate = 0 then 1 else 0 end as skip_never,
	case when b.skip_rate between 1 and 30 then 1 else 0 end as skip_low,
	-- listening pattern
	case when b.days_played > 50 then 1 else 0 end as pattern_long_term,
	case when b.days_played between 21 and 50 then 1 else 0 end as pattern_regular,
	case when b.days_played between 11 and 20 then 1 else 0 end as pattern_occasional,
	case when b.days_played <= 10 then 1 else 0 end as pattern_rare
from base b;


-- clean track_features_engineered
create view track_features_clean as
with base as (
	select 
		track_id,
		ln(1 + total_plays::double precision) as log_total_plays,
		ln(1 + total_skips::double precision) as log_total_skips,
		ln(1 + days_played::double precision) as log_days_played,
		ln(1 + (extract(epoch from listening_period) / 86400.0)) as log_listening_period,
		ln(1 + skip_adjusted_popularity::double precision) as log_skip_adj_pop,
		session_intensity,
		recency_score,
		loyalty_index,
		genre_diversity,
		affinity_loved,
		affinity_liked,
		affinity_casual,
		affinity_tried,
		skip_high,
		skip_moderate,
		skip_never,
		skip_low,
		pattern_long_term,
		pattern_regular,
		pattern_occasional,
		pattern_rare
	from track_features_engineered
),
stats as (
	select 
		avg(log_total_plays) as mean_log_total_plays,
		stddev_pop(log_total_plays) as sd_log_total_plays,
		avg(log_total_skips) as mean_log_total_skips,
		stddev_pop(log_total_skips) as sd_log_total_skips,
		avg(log_days_played) as mean_log_days_played,
		stddev_pop(log_days_played) as sd_log_days_played,
		avg(log_listening_period) as mean_log_listening_period,
		stddev_pop(log_listening_period) as sd_log_listening_period,
		avg(session_intensity) as mean_session_intensity,
		avg(log_skip_adj_pop) as mean_log_skip_adj_pop,
        stddev_pop(log_skip_adj_pop) as sd_log_skip_adj_pop,
		stddev_pop(session_intensity) as sd_session_intensity,
		avg(recency_score) as mean_recency_score,
		stddev_pop(recency_score) as sd_recency_score,
		avg(loyalty_index) as mean_loyalty_index,
		stddev_pop(loyalty_index) as sd_loyalty_index,
		avg(genre_diversity) as mean_genre_diversity,
		stddev_pop(genre_diversity) as sd_genre_diversity
	from base
)
	
select
	b.track_id,
	(b.log_total_plays - s.mean_log_total_plays) / nullif(s.sd_log_total_plays, 0)
		as z_log_total_plays,
	(b.log_total_skips - s.mean_log_total_skips) / nullif(s.sd_log_total_skips, 0)
		as z_log_total_skips,
	(b.log_days_played - s.mean_log_days_played) / nullif(s.sd_log_days_played, 0)
		as z_log_days_played,
	(b.log_listening_period - s.mean_log_listening_period) / nullif(s.sd_log_listening_period, 0)
		as z_log_listening_period,
	(b.log_skip_adj_pop - s.mean_log_skip_adj_pop) / nullif(s.sd_log_skip_adj_pop, 0)
		as z_log_skip_adj_pop,
	(b.session_intensity - s.mean_session_intensity) / nullif(s.sd_session_intensity, 0)
		as z_session_intensity,
	(b.recency_score - s.mean_recency_score) / nullif(s.sd_recency_score, 0)
		as z_recency_score,
	(b.loyalty_index - s.mean_loyalty_index) / nullif(s.sd_loyalty_index, 0)
		as z_loyalty_index,
	(b.genre_diversity - s.mean_genre_diversity) / nullif(s.sd_genre_diversity, 0)
		as z_genre_diversity,
	affinity_loved,
	affinity_liked,
	affinity_casual,
	affinity_tried,
	skip_high,
	skip_moderate,
	skip_never,
	skip_low,
	pattern_long_term,
	pattern_regular,
	pattern_occasional,
	pattern_rare
from base b
cross join stats s;