-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. 
	-- As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

--To "eyeball" the answer, consider: Do teams that pay an above average salary amount in a given year win an above average number of games that year?

WITH avg_wins AS
	-- find the average number of wins per year
	(SELECT yearid, ROUND(AVG(w)) AS avg_wins
	FROM teams
	WHERE yearid >= 2000
	GROUP BY yearid), 

team_salaries AS
	-- find total team salaries per year & team
	(SELECT teamid, yearid, SUM(salary)::numeric::money AS total_salaries
	FROM salaries
	WHERE yearid >= 2000
	GROUP BY teamid, yearid),

avg_salaries AS
	-- then find average team salaries per year
	(SELECT yearid, AVG(total_salaries::numeric)::money AS avg_team_salary
	FROM team_salaries
	GROUP BY yearid),

num_teams AS
	-- then count the number of teams per year
	(SELECT yearid, COUNT(DISTINCT teamid) AS num_teams
	FROM teams 
	WHERE yearid >= 2000
	GROUP BY yearid),

correlations AS 
	-- then filter for teams that experienced a correlation between their total salary compared to the mean and their number of wins compared to the mean
	(SELECT yearid, COUNT(*) AS correlations
	FROM teams INNER JOIN avg_wins USING(yearid)
			   INNER JOIN team_salaries USING(teamid, yearid)
			   INNER JOIN avg_salaries USING(yearid)
	WHERE (total_salaries > avg_team_salary AND w > avg_wins)
		OR (total_salaries < avg_team_salary AND w < avg_wins)
	GROUP BY yearid)


--What percentage of teams experienced a positive correlation between their salary and number of wins, as compared to averages for that year?
SELECT yearid, ROUND((correlations::numeric/num_teams::numeric)*100, 2) AS perc_teams_correlated
FROM correlations INNER JOIN num_teams USING(yearid)
; -- In most years, there does appear to be a slight correlation between salaries and wins. 




-- 12. In this question, you will explore the connection between number of wins and attendance. 
	-- Does there appear to be any correlation between attendance at home games and number of wins? 

--To "eyeball" the answer, consider: if a team wins a higher percentage of their games than the previous year, do they also have higher attendance per game?
WITH att_per_h_game AS
	-- attendance per home game each year
	(SELECT 
		team, year, 
		SUM(attendance)/SUM(games) AS att_per_h_game
	FROM homegames
	WHERE attendance IS NOT NULL
		AND attendance > 0
	GROUP BY team, year),

total_records AS
	-- each team's win rate and attendance per game for every year
	(SELECT t1.teamid, t1.name, 
		t1.yearid, ROUND((t1.w::numeric/t1.g::numeric)*100,2) AS win_rate, 		a1.att_per_h_game,
		t2.yearid, ROUND((t2.w::numeric/t2.g::numeric)*100,2) AS prev_win_rate, a2.att_per_h_game AS prev_att_per_h_game
	FROM teams AS t1 INNER JOIN att_per_h_game AS a1 ON t1.teamid = a1.team AND t1.yearid = a1.year
					 LEFT JOIN teams AS t2 ON t1.teamid = t2.teamid AND t1.yearid -1 = t2.yearid
					 LEFT JOIN att_per_h_game AS a2 ON t1.teamid = a2.team AND t2.yearid = a2.year
	WHERE t2.g IS NOT NULL), 

correlated_records AS
	-- total records filtered for years where the win rate and attendance per game were both higher
	(SELECT *
	FROM total_records
	WHERE win_rate >= prev_win_rate
		AND att_per_h_game >= prev_att_per_h_game)

-- calculated as percentage
SELECT 
	ROUND((((SELECT COUNT(*)::numeric FROM correlated_records)/COUNT(*)::numeric)*100),2) AS perc_corr_years
FROM total_records 
; --A team's attendance-per-home-game increases if they are winning more of their games than in the previous season only 32% of the time


--12. (cont) Do teams that win the world series see a boost in attendance the following year? 
WITH att_per_h_game AS
	-- attendance per home game each year
	(SELECT 
		team, year, 
		SUM(attendance)/SUM(games) AS att_per_h_game
	FROM homegames
	WHERE attendance IS NOT NULL
		AND attendance > 0
	GROUP BY team, year),
	
wswins AS
	-- world series winners with their that-year and next-year attendance per game numbers
	(SELECT teamid, name, 
		yearid, wswin, a1.att_per_h_game,
		a2.year AS next_year, a2.att_per_h_game AS next_att_per_h_game
	FROM teams LEFT JOIN att_per_h_game AS a1 ON teamid = a1.team AND yearid = a1.year
			   LEFT JOIN att_per_h_game AS a2 ON teamid = a2.team AND yearid + 1 = a2.year
	WHERE wswin = 'Y'
		AND a1.att_per_h_game IS NOT NULL
		AND a2.att_per_h_game IS NOT NULL
	),

boosted_att AS
	-- filtered for years where attendance per game increased after winning
	(SELECT *
	FROM wswins
	WHERE next_att_per_h_game > att_per_h_game)

-- calculated as percentage
SELECT 
	ROUND(((SELECT COUNT(*)::numeric FROM boosted_att)/COUNT(*)::numeric)*100,2)
FROM wswins

; -- home game attendance per game is higher the year after winning a WS 53% of the time


--12. (cont) What about teams that made the playoffs?  Making the playoffs means either being a division winner or a wild card winner. 
WITH att_per_h_game AS
	(SELECT 
		team, year, 
		SUM(attendance)/SUM(games) AS att_per_h_game
	FROM homegames
	WHERE attendance IS NOT NULL
		AND attendance > 0
	GROUP BY team, year),
	
playoff_wins AS
(SELECT teamid, name, 
		yearid, divwin, wcwin,	a1.att_per_h_game,
		a2.year AS next_year, a2.att_per_h_game AS next_att_per_h_game
	FROM teams LEFT JOIN att_per_h_game AS a1 ON teamid = a1.team AND yearid = a1.year
			   LEFT JOIN att_per_h_game AS a2 ON teamid = a2.team AND yearid + 1 = a2.year
	WHERE (divwin = 'Y') OR (wcwin = 'Y')
		AND a1.att_per_h_game IS NOT NULL
		AND a2.att_per_h_game IS NOT NULL),

boosted_att AS
	(SELECT * 
	FROM playoff_wins
	WHERE next_att_per_h_game > att_per_h_game)

SELECT 
	ROUND(((SELECT COUNT(*)::numeric FROM boosted_att)/COUNT(*)::numeric)*100,2)
FROM playoff_wins
; -- home game attendance-per-game is higher the year after winning the playoffs 56% of the time


/* 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. 
	Investigate this claim and present evidence to either support or dispute this claim. 
	First, determine just how rare left-handed pitchers are compared with right-handed pitchers. */

WITH pitchers AS
	(SELECT DISTINCT playerid, throws
	FROM pitching LEFT JOIN people USING(playerid)
	WHERE throws IS NOT NULL)

SELECT throws, 
	COUNT(distinct playerid),
	ROUND((COUNT(distinct playerid)::numeric / (SELECT COUNT(DISTINCT playerid)::numeric FROM pitchers)) * 100, 1) AS perc
FROM pitchers
GROUP BY GROUPING SETS((throws), ())
ORDER BY throws
; -- 27% of all pitchers are lefties


-- Are left-handed pitchers more likely to win the Cy Young Award?
WITH pitchers AS
	(SELECT DISTINCT playerid, throws
	FROM pitching LEFT JOIN people USING(playerid)
	WHERE Throws IS NOT NULL)
	
SELECT throws,
	COUNT(*),
	ROUND((COUNT(*)::numeric / (SELECT COUNT(*)::numeric FROM awardsplayers WHERE awardid = 'Cy Young Award')) * 100, 2) AS perc
FROM awardsplayers LEFT JOIN pitchers USING(playerid)
WHERE awardid = 'Cy Young Award'
GROUP BY GROUPING SETS((throws), ())
ORDER BY throws
; -- Left-handed pitchers win the Cy Young award 33% of the time, which is more often than you would expect given their rate of prevalance in the sport


--Are they [left-handed pitchers] more likely to make it into the hall of fame?
WITH pitchers AS
	(SELECT DISTINCT playerid, throws
	FROM pitching LEFT JOIN people USING(playerid)
	WHERE throws IS NOT NULL),

halloffame_pitchers AS
	(SELECT playerid FROM pitchers
	INTERSECT
	SELECT playerid FROM halloffame	WHERE inducted = 'Y')

SELECT throws,
	COUNT(*), 
	ROUND((COUNT(*)::numeric / (SELECT COUNT(*)::numeric FROM halloffame_pitchers)) * 100, 2) AS perc
FROM halloffame_pitchers LEFT JOIN pitchers USING(playerid)
GROUP BY GROUPING SETS ((throws), ())
ORDER BY throws
; -- Left-handed pitchers are actually *under* represented in the Hall of Fame, being only 23% of pitchers inducted in


-- Comparison of pitching stats (strikeouts per batters faced, ERA, BAOpp) across pitcher handedness
	-- interesting note: walks, strikeouts, and ERA go back to 1871.  BAOpp and BFP are much newer stats

WITH career_totals AS
	-- getting the relevant career total stats for players whose handedness is known and who pitched in at least 10 games
	(SELECT playerid, throws::text, 
		SUM(g) AS g,
		SUM(h) AS h, SUM(BFP) AS BFP, SUM(BB) AS bb, SUM(hbp) AS hbp, SUM(sh) AS sh, SUM(sf) AS sf,
		SUM(er) AS er, SUM(IPouts) AS IPouts, SUM(SO) AS so
	FROM pitching LEFT JOIN people USING(playerid)
	WHERE throws IS NOT NULL
	GROUP BY playerid, throws
		HAVING SUM(g) >= 10)

SELECT throws,
		--calculate an overall opponents' batting average
		ROUND(SUM(h)::numeric / (SUM(BFP) - SUM(BB) - SUM(HBP) - SUM(SH) - SUM(SF))::numeric, 3) AS overall_BAOpp,
		--calculate an overall ERA 
		ROUND(SUM(er)::numeric / (SUM(IPouts)::numeric / 3) *9, 2) AS overall_era,
		--calculate overall SO per batter faced
		ROUND((SUM(SO)::numeric/SUM(BFP)::numeric), 3) AS overall_so_per_batter
FROM career_totals
	WHERE throws IN ('L', 'R')
GROUP BY GROUPING SETS ((throws), ())
ORDER BY throws
;
