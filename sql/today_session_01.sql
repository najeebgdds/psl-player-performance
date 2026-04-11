
-- View 1: Season summary (winners, matches, etc.)

CREATE OR REPLACE VIEW v_season_summary AS
SELECT 
    season,
    winner,
    COUNT(*) AS matches_played,
    COUNT(DISTINCT match_id) AS unique_matches
FROM psl_matches
GROUP BY season, winner
ORDER BY season, matches_played DESC;
-- test
SELECT * FROM v_season_summary LIMIT 10;


--Create View 2 – Top batters per season

CREATE OR REPLACE VIEW v_top_batters_season AS
SELECT 
    season,
    batter,
    SUM(batsman_runs) AS total_runs,
    COUNT(*) AS balls_faced,
    ROUND(100.0 * SUM(batsman_runs) / COUNT(*), 1) AS strike_rate
FROM psl_deliveries
WHERE batter IS NOT NULL
GROUP BY season, batter
HAVING COUNT(*) >= 50  -- minimum 50 balls
ORDER BY season, total_runs DESC;

-- test
SELECT * FROM v_top_batters_season LIMIT 10;


-- Step 3: View 3 – Top bowlers per season
CREATE OR REPLACE VIEW v_top_bowlers_season AS
SELECT 
    season,
    bowler,
    COUNT(*) AS balls_bowled,
    SUM(total_runs) AS runs_conceded,
    SUM(is_wicket::int) AS wickets,
    ROUND(100.0 * SUM(total_runs) / COUNT(*), 1) AS economy
FROM psl_deliveries
WHERE bowler IS NOT NULL
GROUP BY season, bowler
HAVING COUNT(*) >= 50  -- minimum 50 balls
ORDER BY season, wickets DESC, economy ASC;
--test
SELECT * FROM v_top_bowlers_season LIMIT 10;


-- Save these views to file for reference
--\copy (SELECT pg_get_viewdef('v_season_summary'::regclass)) TO '/tmp/views.sql';

