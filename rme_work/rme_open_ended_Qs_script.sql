-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. 
	-- As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

--First attempt, using rankings
WITH team_wins AS
	(SELECT teamid, name, yearid, SUM(w) AS num_wins
	FROM teams
	WHERE yearid >= 2000
	GROUP BY teamid, name, yearid
	ORDER BY yearid),

team_salaries AS
	(SELECT teamid, yearid, SUM(salary)::numeric::money AS total_salaries
	FROM salaries
	WHERE yearid >= 2000
	GROUP BY teamid, yearid)

SELECT yearid, name, num_wins, total_salaries, 
	RANK() OVER(PARTITION BY yearid ORDER BY num_wins DESC) AS win_rank, 
	RANK() OVER(PARTITION BY yearid ORDER BY total_salaries DESC) AS salary_rank
FROM team_wins INNER JOIN team_salaries USING(teamid, yearid)
;

--Second attempt: Do teams that pay an above average salary amount in a given year win an above average number of games that year?

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
; -- In most years, there does appear to be a slight correlation between salaries and wins. Determining the strength and nature of the correlation would require more statistics work.


-- 12. In this question, you will explore the connection between number of wins and attendance. 
	-- Does there appear to be any correlation between attendance at home games and number of wins? 

--Answering by: if a team wins a higher percentage of their games than the previous year, do they also have higher attendance per game?
WITH total_records AS
	(SELECT t1.teamid, t1.name, 
		t1.yearid, 				ROUND((t1.w::numeric/t1.g::numeric)*100,2) AS win_rate, 	  (t1.attendance/t1.g) AS att_per_game,
		t2.yearid AS prev_year, ROUND((t2.w::numeric/t2.g::numeric)*100, 2) AS prev_win_rate, (t2.attendance/t2.g) AS prev_att_per_game
	FROM teams AS t1 LEFT JOIN teams AS t2 ON t1.teamid = t2.teamid AND t1.yearid -1 = t2.yearid
	WHERE t2.attendance IS NOT NULL
	),

correlated_records AS
	(SELECT *
	FROM total_records
	WHERE win_rate >= prev_win_rate
		AND att_per_game >= prev_att_per_game)

SELECT 
	ROUND((((SELECT COUNT(*)::numeric FROM correlated_records)/COUNT(*)::numeric)*100),2) AS perc_corr_years
FROM total_records
; --A team's attendance-per-home-game increases if they are winning more of their games than in the previous season only 34% of the time


--12. (cont) Do teams that win the world series see a boost in attendance the following year? 

WITH wswins AS
	(SELECT t1.teamid, t1.name, 
		t1.yearid, t1.wswin, (t1.attendance/t1.g) AS att_per_game,
		t2.yearid AS next_year, (t2.attendance/t2.g) AS next_att_per_game
	FROM teams AS t1 LEFT JOIN teams AS t2 ON t1.teamid = t2.teamid AND t1.yearid + 1 = t2.yearid
	WHERE t1.wswin = 'Y'
		AND t1.attendance IS NOT NULL
		AND t2.attendance IS NOT NULL),

boosted_att AS
	(SELECT *
	FROM wswins
	WHERE next_att_per_game > att_per_game)

SELECT 
	ROUND(((SELECT COUNT(*)::numeric FROM boosted_att)/COUNT(*)::numeric)*100,2)
FROM wswins
; -- home game attendance per game is higher the year after winning a WS 52% of the time


--12. (cont) What about teams that made the playoffs?  Making the playoffs means either being a division winner or a wild card winner. 
WITH playoff_wins AS
(SELECT t1.teamid, t1.name, 
		t1.yearid, t1.divwin, t1.wcwin, (t1.attendance/t1.g) AS att_per_game,
		t2.yearid AS next_year, (t2.attendance/t2.g) AS next_att_per_game
	FROM teams AS t1 LEFT JOIN teams AS t2 ON t1.teamid = t2.teamid AND t1.yearid + 1 = t2.yearid
	WHERE (t1.divwin = 'Y') OR (t1.wcwin = 'Y')
		AND t1.attendance IS NOT NULL
		AND t2.attendance IS NOT NULL),

boosted_att AS
	(SELECT * 
	FROM playoff_wins
	WHERE next_att_per_game > att_per_game)

SELECT 
	ROUND(((SELECT COUNT(*)::numeric FROM boosted_att)/COUNT(*)::numeric)*100,2)
FROM playoff_wins
; -- home game attendance-per-game is higher the year after winning the playoffs 56% of the time


/* 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. 
	Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers.
	Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame? */