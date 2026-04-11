
SELECT COUNT(*) FROM deliveries;


SELECT season, COUNT(*) 
FROM deliveries 
GROUP BY season 
ORDER BY season;

-- 1. Batting Summary

CREATE OR REPLACE VIEW v_batting AS
SELECT season, batter, 
    SUM(batsman_runs) AS runs,
    COUNT(*) AS balls,
    ROUND(SUM(batsman_runs)::numeric / NULLIF(COUNT(*),0) * 100, 1) AS strike_rate
FROM deliveries 
GROUP BY season, batter
ORDER BY season, runs DESC;

-- test
SELECT * FROM v_batting WHERE batter = 'Babar Azam';
SELECT * FROM v_batting WHERE batter = 'Mohammad Rizwan';

-- 2. Bowling Summary

CREATE OR REPLACE VIEW v_bowling AS
SELECT season, bowler,
    COUNT(*) AS balls,
    SUM(total_runs) AS runs_conceded,
    COUNT(*) FILTER (WHERE is_wicket = true) AS wickets,
    ROUND(SUM(total_runs)::numeric / NULLIF(COUNT(*), 0), 1) AS economy
FROM deliveries 
GROUP BY season, bowler
ORDER BY season, wickets DESC;

-- test
SELECT * FROM v_bowling WHERE bowler = 'Umar Gul';
SELECT * FROM v_bowling WHERE bowler = 'Naseem Shah';

-- Team Performance

CREATE OR REPLACE VIEW v_team_stats AS
SELECT season, batting_team AS team,
    COUNT(*) FILTER (WHERE winner = batting_team) AS wins,
    COUNT(*) FILTER (WHERE winner = bowling_team) AS losses,
    AVG(total_runs) FILTER (WHERE inning = 1) AS avg_1st_inn_score
FROM deliveries 
GROUP BY season, batting_team
ORDER BY season, wins DESC;


-- Test
SELECT * FROM v_team_stats WHERE team = 'Karachi Kings' ORDER BY season;

