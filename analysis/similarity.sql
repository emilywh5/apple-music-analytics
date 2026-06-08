-- find 10 most similar songs to a given song in my listening history
with target as (
	select
		c.track_id,
        c.z_log_total_plays,
        c.z_log_total_skips,
        c.z_log_days_played,
        c.z_log_listening_period,
        c.z_log_skip_adj_pop,
        c.z_session_intensity,
        c.z_recency_score,
        c.z_loyalty_index,
        c.z_genre_diversity,
        c.affinity_loved,
        c.affinity_liked,
        c.affinity_casual,
        c.affinity_tried,
        c.skip_high,
        c.skip_moderate,
        c.skip_low,
        c.skip_never,
        c.pattern_long_term,
        c.pattern_regular,
        c.pattern_occasional,
        c.pattern_rare
	from track_features_clean c
	join track_features_engineered e on c.track_id = e.track_id
	where title = 'Stateside (with Zara Larsson)'
      and artist = 'PinkPantheress'
),
target_norm as (
    select sqrt(
        power(t.z_log_total_plays, 2) +
        power(t.z_log_total_skips, 2) +
        power(t.z_log_days_played, 2) +
        power(t.z_log_listening_period, 2) +
        power(t.z_log_skip_adj_pop, 2) +
        power(t.z_session_intensity, 2) +
        power(t.z_recency_score, 2) +
        power(t.z_loyalty_index, 2) +
        power(t.z_genre_diversity, 2) +
        power(t.affinity_loved, 2) +
        power(t.affinity_liked, 2) +
        power(t.affinity_casual, 2) +
        power(t.affinity_tried, 2) +
        power(t.skip_high, 2) +
        power(t.skip_moderate, 2) +
        power(t.skip_low, 2) +
        power(t.skip_never, 2) +
        power(t.pattern_long_term, 2) +
        power(t.pattern_regular, 2) +
        power(t.pattern_occasional, 2) +
        power(t.pattern_rare, 2)
    ) as norm
    from target t
),
similarities as (
	select
    	e.title,
    	e.artist,
    	e.genres,
    	-- Cosine similarity = dot_product / (norm_a * norm_b)
    	(
        	(
            	c.z_log_total_plays * t.z_log_total_plays +
        	    c.z_log_total_skips * t.z_log_total_skips +
            	c.z_log_days_played * t.z_log_days_played +
            	c.z_log_listening_period * t.z_log_listening_period +
            	c.z_log_skip_adj_pop * t.z_log_skip_adj_pop +
            	c.z_session_intensity * t.z_session_intensity +
            	c.z_recency_score * t.z_recency_score +
            	c.z_loyalty_index * t.z_loyalty_index +
            	c.z_genre_diversity * t.z_genre_diversity +
            	c.affinity_loved * t.affinity_loved +
            	c.affinity_liked * t.affinity_liked +
            	c.affinity_casual * t.affinity_casual +
            	c.affinity_tried * t.affinity_tried +
            	c.skip_high * t.skip_high +
            	c.skip_moderate * t.skip_moderate +
            	c.skip_low * t.skip_low +
            	c.skip_never * t.skip_never +
            	c.pattern_long_term * t.pattern_long_term +
            	c.pattern_regular * t.pattern_regular +
            	c.pattern_occasional * t.pattern_occasional +
            	c.pattern_rare * t.pattern_rare
        	) 
        	/ 
        	(
        		sqrt(
        			power(c.z_log_total_plays, 2) +
                	power(c.z_log_total_skips, 2) +
                	power(c.z_log_days_played, 2) +
                	power(c.z_log_listening_period, 2) +
                	power(c.z_log_skip_adj_pop, 2) +
                	power(c.z_session_intensity, 2) +
                	power(c.z_recency_score, 2) +
                	power(c.z_loyalty_index, 2) +
                	power(c.z_genre_diversity, 2) +
                	power(c.affinity_loved, 2) +
                	power(c.affinity_liked, 2) +
                	power(c.affinity_casual, 2) +
                	power(c.affinity_tried, 2) +
                	power(c.skip_high, 2) +
                	power(c.skip_moderate, 2) +
                	power(c.skip_low, 2) +
                	power(c.skip_never, 2) +
                	power(c.pattern_long_term, 2) +
                	power(c.pattern_regular, 2) +
                	power(c.pattern_occasional, 2) +
                	power(c.pattern_rare, 2)
            	) * tn.norm
        	)
    	) as cosine_similarity
	from track_features_clean c
	join track_features_engineered e on c.track_id = e.track_id
	cross join target t
	cross join target_norm tn
	where c.track_id != t.track_id
)
select *
from similarities
where cosine_similarity is not null
order by cosine_similarity desc
limit 10;