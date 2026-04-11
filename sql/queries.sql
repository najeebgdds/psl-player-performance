-- Most runs per season (top 3)
WITH ranked_batters AS (
    SELECT season, batter, SUM(batsman_runs) AS total_runs,
        ROW_NUMBER() OVER (PARTITION BY season ORDER BY SUM(batsman_runs) DESC) as rn
    FROM deliveries 
    GROUP BY season, batter
)
SELECT season, batter, total_runs
FROM ranked_batters 
WHERE rn <= 3
ORDER BY season, total_runs DESC;

--Babar's top-3 consistency query:
WITH babar_ranking AS (
    SELECT season, batter, SUM(batsman_runs) AS total_runs,
        ROW_NUMBER() OVER (PARTITION BY season ORDER BY SUM(batsman_runs) DESC) as rn
    FROM deliveries 
    GROUP BY season, batter
)
SELECT COUNT(*) AS top_3_finishes,
    ROUND(AVG(total_runs), 0) AS avg_top3_runs
FROM babar_ranking 
WHERE batter = 'Babar Azam' AND rn <= 3;

-- Babar's full ranking history:

WITH babar_ranking AS (
    SELECT season, SUM(batsman_runs) AS runs,
        ROW_NUMBER() OVER (PARTITION BY season ORDER BY SUM(batsman_runs) DESC) as rank
    FROM deliveries 
    WHERE batter = 'Babar Azam'
    GROUP BY season
)
SELECT season, runs, rank FROM babar_ranking ORDER BY season;


-- Query #2: Team Win % Evolution

SELECT season, batting_team AS team,
    ROUND(COUNT(*) FILTER (WHERE winner = batting_team) * 100.0 / COUNT(*), 1) AS win_pct,
    COUNT(*) FILTER (WHERE winner = batting_team) AS wins
FROM deliveries 
GROUP BY season, batting_team
HAVING COUNT(*) > 100
ORDER BY team, season;

-- Phase 2: Window Functions (Career Progression)
--  Batter Improvement (This vs Last Season)

WITH batter_evolution AS (
    SELECT season, batter, SUM(batsman_runs) AS runs,
        LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS prev_runs,
        SUM(batsman_runs) - LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS run_improvement
    FROM deliveries 
    GROUP BY season, batter
)
SELECT season, batter, runs, prev_runs, run_improvement
FROM batter_evolution 
WHERE batter IN ('Babar Azam', 'Fakhar Zaman', 'Mohammad Rizwan')
ORDER BY batter, season;

-- lets add matches and strike rate to career progression:

WITH batter_evolution AS (
    SELECT season, batter, 
        SUM(batsman_runs) AS runs,
        COUNT(*) AS balls_faced,
        ROUND(SUM(batsman_runs)::numeric / NULLIF(COUNT(*),0) * 100, 1) AS strike_rate,
        COUNT(DISTINCT match_id) AS matches,
        LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS prev_runs,
        SUM(batsman_runs) - LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS run_improvement
    FROM deliveries 
    GROUP BY season, batter
)
SELECT season, batter, matches, runs, strike_rate, 
       prev_runs, run_improvement
FROM batter_evolution 
WHERE batter IN ('Babar Azam', 'Fakhar Zaman', 'Mohammad Rizwan')
ORDER BY batter, season;


WITH batter_evolution AS (
    SELECT season, batter, 
        SUM(batsman_runs) AS runs,
        COUNT(*) AS balls_faced,
        ROUND(SUM(batsman_runs)::numeric / NULLIF(COUNT(*),0) * 100, 1) AS strike_rate,
        COUNT(DISTINCT match_id) AS matches,
        LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS prev_runs,
        SUM(batsman_runs) - LAG(SUM(batsman_runs)) OVER (PARTITION BY batter ORDER BY season) AS run_improvement
    FROM deliveries 
    GROUP BY season, batter
)
SELECT season, batter, matches, runs, strike_rate, 
       prev_runs, run_improvement
FROM batter_evolution 
WHERE batter IN ('Babar Azam', 'Fakhar Zaman', 'Mohammad Rizwan')
ORDER BY batter, season;


-- Query #4: Bowler Economy Progression

WITH bowler_evolution AS (
    SELECT season, bowler,
        COUNT(*) AS balls,
        SUM(total_runs) AS runs_conceded,
        COUNT(*) FILTER (WHERE is_wicket = true) AS wickets,
        ROUND(SUM(total_runs)::numeric / COUNT(*), 1) AS economy,
        LAG(ROUND(SUM(total_runs)::numeric / COUNT(*), 1)) 
            OVER (PARTITION BY bowler ORDER BY season) AS prev_economy,
        ROUND(SUM(total_runs)::numeric / COUNT(*), 1) - 
            LAG(ROUND(SUM(total_runs)::numeric / COUNT(*), 1)) 
            OVER (PARTITION BY bowler ORDER BY season) AS econ_change
    FROM deliveries 
    GROUP BY season, bowler
)
SELECT season, bowler, balls, wickets, economy, prev_economy, econ_change
FROM bowler_evolution
WHERE bowler IN ('Naseem Shah', 'Shaheen Afridi', 'Wahab Riaz')
ORDER BY bowler, season;

-- Query #5: Highest Partnerships (by wicket number)

WITH pair_runs AS (
    SELECT 
        LEAST(batter, non_striker) AS batsman1,
        GREATEST(batter, non_striker) AS batsman2,
        SUM(batsman_runs + extra_runs) AS partnership_runs,
        COUNT(*) AS balls_faced
    FROM deliveries 
    GROUP BY 1, 2
    HAVING COUNT(*) >= 50  -- meaningful partnerships
)
SELECT batsman1, batsman2, partnership_runs, balls_faced,
    ROUND(partnership_runs * 100.0 / balls_faced, 1) AS run_rate
FROM pair_runs 
ORDER BY partnership_runs DESC 
LIMIT 10;


-- individual contributions within partnerships!

WITH raw_partnerships AS (
    SELECT batter, non_striker,
        SUM(batsman_runs + extra_runs) AS total_runs,
        COUNT(*) AS balls_faced
    FROM deliveries 
    GROUP BY batter, non_striker
    HAVING COUNT(*) >= 50
),
pair_summary AS (
    SELECT 
        LEAST(batter, non_striker) AS batsman1,
        GREATEST(batter, non_striker) AS batsman2,
        MAX(total_runs) AS partnership_runs,
        MAX(balls_faced) AS balls_faced
    FROM raw_partnerships 
    GROUP BY 1, 2
),
bat1_contrib AS (
    SELECT batsman1, batsman2, partnership_runs, balls_faced,
        SUM(CASE WHEN batter = batsman1 THEN batsman_runs ELSE 0 END) AS bat1_runs
    FROM deliveries d
    JOIN pair_summary p ON (LEAST(d.batter, d.non_striker) = p.batsman1 
                          AND GREATEST(d.batter, d.non_striker) = p.batsman2)
    GROUP BY 1,2,3,4
)
SELECT batsman1, ROUND(bat1_runs, 0) AS bat1_runs,
       batsman2, ROUND(partnership_runs - bat1_runs, 0) AS bat2_runs,
       partnership_runs, balls_faced,
       ROUND(bat1_runs * 100.0 / partnership_runs, 1) AS bat1_pct
FROM bat1_contrib 
ORDER BY partnership_runs DESC 
LIMIT 10;

-- #6: Home/Away Venue Dominance

WITH home_away_stats AS (
    SELECT venue, batting_team,
        COUNT(*) FILTER (WHERE winner = batting_team) * 100.0 / COUNT(*) AS win_pct,
        AVG(total_runs) AS avg_score
    FROM deliveries 
    GROUP BY venue, batting_team
)
SELECT venue, batting_team, 
       ROUND(win_pct, 1) AS home_win_pct,
       ROUND(avg_score, 1) AS avg_score
FROM home_away_stats 
WHERE venue IN (
    'Gaddafi Stadium, Lahore', 
    'National Stadium, Karachi',
    'Multan Cricket Stadium', 
    'Dubai International Cricket Stadium'
)
ORDER BY venue, win_pct DESC 
LIMIT 30;

-- Phase 3: Phase Analysis (#7 Powerplay vs Death Overs)

SELECT 
    CASE 
        WHEN over BETWEEN 1 AND 6 THEN 'Powerplay'
        WHEN over BETWEEN 16 AND 20 THEN 'Death Overs' 
        ELSE 'Middle Overs'
    END AS phase,
    bowling_team,
    COUNT(*) AS balls,
    SUM(total_runs) AS runs,
    COUNT(*) FILTER (WHERE is_wicket = true) AS wickets,
    ROUND(SUM(total_runs)::numeric / COUNT(*), 1) AS econ
FROM deliveries 
WHERE over BETWEEN 1 AND 20
GROUP BY 1, 2
ORDER BY phase, econ ASC 
LIMIT 20;

-- Most Boundaries per Team!

WITH boundaries AS (
    SELECT batting_team, batter,
        COUNT(*) FILTER (WHERE batsman_runs = 4) AS fours,
        COUNT(*) FILTER (WHERE batsman_runs = 6) AS sixes,
        COUNT(*) FILTER (WHERE batsman_runs IN (4,6)) AS total_boundaries
    FROM deliveries 
    GROUP BY batting_team, batter
)
SELECT batting_team, batter, fours, sixes, total_boundaries
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY batting_team ORDER BY total_boundaries DESC) as rn
    FROM boundaries
) ranked
WHERE rn = 1
ORDER BY total_boundaries DESC;


-- See available columns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'deliveries' 
AND column_name LIKE '%over%' OR column_name LIKE '%ball%';

-- Boundaries in Powerplay

WITH powerplay_boundaries AS (
    SELECT batting_team, batter,
        COUNT(*) FILTER (WHERE batsman_runs IN (4,6) 
                        AND over <= 6) AS pp_boundaries
    FROM deliveries 
    WHERE over <= 6
    GROUP BY batting_team, batter
)
SELECT batting_team, batter, pp_boundaries
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY batting_team ORDER BY pp_boundaries DESC) rn
    FROM powerplay_boundaries
) ranked WHERE rn = 1
ORDER BY pp_boundaries DESC;

--Boundaries in Death Overs (16-20)

WITH death_boundaries AS (
    SELECT batting_team, batter,
        COUNT(*) FILTER (WHERE batsman_runs IN (4,6) 
                        AND over >= 16) AS death_boundaries
    FROM deliveries 
    WHERE over >= 16
    GROUP BY batting_team, batter
)
SELECT batting_team, batter, death_boundaries
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY batting_team ORDER BY death_boundaries DESC) rn
    FROM death_boundaries
) ranked WHERE rn = 1
ORDER BY death_boundaries DESC;

