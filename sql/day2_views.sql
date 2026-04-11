-- Day 2
--Step 2: Quick test (confirm we’re good)

SELECT COUNT(*) FROM psl_matches;  -- 314
SELECT COUNT(*) FROM psl_deliveries;  -- 73784
SELECT * FROM v_season_summary LIMIT 5;

--  View 4 – Venue analysis (your sketch: "Team vs venue win/loss")
CREATE OR REPLACE VIEW v_venue_analysis AS
SELECT
	venue,
	winner,
	count(*) AS matches_won,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY venue), 1) AS win_pct
FROM psl_matches
WHERE winner is NOT NULL
GROUP BY venue,winner
HAVING COUNT(*) >= 3
ORDER BY venue, matches_won DESC;

-- Lets Test it now
SELECT * FROM v_venue_analysis LIMIT 10;

-- per season we change a bit in order by
CREATE OR REPLACE VIEW v_venue_analysis_season AS
SELECT 
    season,
    venue,
    winner,
    COUNT(*) AS matches_won,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY season, venue), 1) AS win_pct
FROM psl_matches
WHERE winner IS NOT NULL
GROUP BY season, venue, winner
HAVING COUNT(*) >= 2
ORDER BY season, venue, matches_won DESC;

-- Lets Test it now
SELECT * FROM v_venue_analysis_season LIMIT 100;

-- View 5: Run rate by phase (Powerplay/Middle/Death)
CREATE OR REPLACE VIEW v_phase_analysis AS
SELECT 
    CASE 
        WHEN over BETWEEN 1 AND 6 THEN 'Powerplay'
        WHEN over BETWEEN 7 AND 15 THEN 'Middle'
        ELSE 'Death'
    END AS phase,
    season,
    batting_team,
    COUNT(*) AS balls,
    SUM(total_runs) AS runs,
    ROUND(100.0 * SUM(total_runs) / COUNT(*), 1) AS run_rate
FROM psl_deliveries
WHERE inning = 1  -- 1st innings only
GROUP BY phase, season, batting_team
HAVING COUNT(*) >= 24  -- minimum 4 overs
ORDER BY phase, season, run_rate DESC;

-- Test:
SELECT * FROM v_phase_analysis LIMIT 100;

SELECT season,batting_team,run_rate
FROM v_phase_analysis 
where season = '2025';

-- See run rate by phase (all seasons, all teams)
SELECT 
    phase,
    ROUND(AVG(run_rate), 1) AS avg_run_rate_all_teams
FROM v_phase_analysis
GROUP BY phase
ORDER BY 
    CASE phase 
        WHEN 'Powerplay' THEN 1 
        WHEN 'Middle' THEN 2 
        WHEN 'Death' THEN 3 
    END;

-- By season (one team)

SELECT 
    phase,
    season,
    run_rate
FROM v_phase_analysis
WHERE batting_team = 'Peshawar Zalmi'
ORDER BY season, phase;

-- Top teams by Death overs run rate
SELECT 
    batting_team,
    AVG(run_rate) AS avg_death_run_rate
FROM v_phase_analysis
WHERE phase = 'Death'
GROUP BY batting_team
ORDER BY avg_death_run_rate DESC
LIMIT 5;

	