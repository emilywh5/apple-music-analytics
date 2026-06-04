-- top songs per year
with song_year as (
	select
		t.title,
		a.name as artist,
		extract(year from p.played_at) as year,
		sum(p.play_count) as plays
	from tracks t
	join artists a on t.artist_id = a.artist_id 
	join plays p on t.track_id = p.track_id
	group by t.title, a.name, extract(year from p.played_at)
),
ranked as (
    select
        *,
        row_number() over (
            partition by year
            order by plays desc
        ) as rank
    from song_year
)

select *
from ranked
where rank <= 10
order by year, rank

-- top artists per year
with artist_year as (
	select
		a.name as artist,
		extract(year from p.played_at) as year,
		sum(p.play_count) as plays
	from artists a
	join tracks t on a.artist_id = t.artist_id 
	join plays p on t.track_id = p.track_id
	group by a.name, extract(year from p.played_at)
),
ranked as (
    select
        *,
        row_number() over (
            partition by year
            order by plays desc
        ) as rank
    from artist_year
)

select *
from ranked
where rank <= 10
order by year, rank

-- top song of every month
with song_month as (
	select
		t.title,
		a.name as artist,
		date_trunc('month', p.played_at) as month,
		sum(p.play_count) as plays
	from tracks t
	join artists a on t.artist_id = a.artist_id 
	join plays p on t.track_id = p.track_id
	group by t.title, a.name, month
),
ranked as (
    select
        *,
        row_number() over (
            partition by month
            order by plays desc
        ) as rank
    from song_month
)

select 
	title,
    artist,
    to_char(month, 'Month') AS month_name,
    to_char(month, 'YYYY-MM') AS year_month, 
    plays
from ranked
where rank <= 1
order by year_month, month_name

-- most repeated songs
select
	t.title,
	a.name as artist,
	count(*) as days_played,
	avg(p.play_count) as avg_per_day,
	rank() over (order by avg(p.play_count) desc) as rank
from tracks t
join artists a on t.artist_id = a.artist_id 
join plays p on t.track_id = p.track_id
group by t.title, a.name

-- artist discovery year
select
	a.name as artist,
	min(p.played_at) as first_listen,
	rank() over (order by min(p.played_at) desc) as rank
from artists a
join tracks t on a.artist_id = t.artist_id 
join plays p on t.track_id = p.track_id 
group by a.name

-- listening per month
with month as (
	select
		sum(p.play_count) as plays,
		date_trunc('month', p.played_at) as month
	from plays p
	group by month
)
select 
	plays,
    to_char(month, 'Month') AS month_name,
    to_char(month, 'YYYY-MM') AS year_month
from month
order by year_month, month_name