-- Q1. What range of years for baseball games played does the provided database cover? 

SELECT
	MIN(yearid) AS min_year,
	MAX(yearid) AS max_year
FROM batting;

-- Q2. Find the name and height of the shortest player in the database. How many games did he play in? What is the name of the team for which he played?

SELECT namefirst,namelast, name,teamid,
	ROUND((height::numeric/12),1) AS heigh_in_feet,
	g_all AS total_games_played
FROM people
	INNER JOIN appearances
		USING (playerid)
	INNER JOIN teams
		USING (teamid)
ORDER by height
LIMIT 1;

-- Q3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

SELECT namefirst,namelast, schoolname,
	SUM(salary)::numeric::money AS total_salary
FROM people
	INNER JOIN salaries
		USING (playerid)
	INNER JOIN (SELECT DISTINCT playerid,schoolid FROM collegeplaying)
		USING (playerid)
	INNER JOIN schools
		USING(schoolid)
WHERE schoolname = 'Vanderbilt University'
GROUP BY namefirst,namelast,schoolname
LIMIT 1;

-- Q4. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

WITH position_group AS(
SELECT yearid,po,
	CASE WHEN POS = 'OF' THEN 'Outfield'
		 WHEN POS IN ('SS','1B','2B','3B') THEN 'Infield'
		 WHEN POS IN ('P','C') THEN 'Battery' ELSE 'no pos'
		 END AS position_group
FROM fielding
	WHERE yearid = 2016)
SELECT position_group,yearid, SUM(po) AS total_po
FROM position_group
GROUP BY position_group,yearid;

-- Q5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends?

WITH decades AS(
SELECT yearid,g,so,hr,
	CASE WHEN yearid BETWEEN 1920 AND 1929 THEN '1920s'
		 WHEN yearid BETWEEN 1930 AND 1939 THEN '1930s'
		 WHEN yearid BETWEEN 1940 AND 1949 THEN '1940s'
		 WHEN yearid BETWEEN 1950 AND 1959 THEN '1950s'
		 WHEN yearid BETWEEN 1960 AND 1969 THEN '1960s'
		 WHEN yearid BETWEEN 1970 AND 1979 THEN '1970s'
		 WHEN yearid BETWEEN 1980 AND 1989 THEN '1980s'
		 WHEN yearid BETWEEN 1990 AND 1999 THEN '1990s'
		 WHEN yearid BETWEEN 2000 AND 2009 THEN '2000s'
		 WHEN yearid BETWEEN 2010 AND 2019 THEN '2010s'
		 END AS decades
FROM teams
WHERE yearid >= 1920)

SELECT decades,
	ROUND(SUM(so)::numeric/SUM(g)/2, 2) AS avg_so_per_game,
	ROUND(SUM(hr)::numeric/SUM(g)/2, 2) AS avg_hr_per_game
FROM decades
GROUP BY decades
ORDER BY decades;

-- Q6.Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases.

WITH base_stats AS(
	SELECT namefirst, namelast, yearid, sb::numeric AS stolen_bases,
		cs::numeric AS caugth_stealing, (sb+cs) AS stolen_base_attempts
	FROM people
		INNER JOIN batting 
			USING (playerid))

	SELECT namefirst, namelast, yearid, stolen_base_attempts, stolen_bases, 
		ROUND((stolen_bases/stolen_base_attempts),2)*100 AS success_rate
	FROM base_stats
		WHERE stolen_base_attempts >= 20 AND yearid ='2016'
	ORDER BY success_rate DESC
	LIMIT 1;

-- Q7. From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion – determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

	-- From 1970 – 2016, what is the largest number of wins for a team that did not win the world series?
	
	SELECT yearid, name, SUM(w) AS total_wins
	FROM teams
		WHERE yearid BETWEEN 1910 AND 2016 AND wswin ='N'
	GROUP BY yearid,name
	ORDER BY total_wins DESC
	LIMIT 1;

	-- What is the smallest number of wins for a team that did win the world series? -- This was due to a shortend MLB season casued by a mid season strike.
	
	SELECT yearid, name, SUM(w) AS total_wins
	FROM teams
		WHERE yearid BETWEEN 1910 AND 2016 AND wswin ='Y'
	GROUP BY yearid, name
	ORDER BY total_wins
	LIMIT 1;

	-- How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? 
				-- 1994 was excluded becasue no World Series was completed due to strike.

	WITH team_wins AS(
		SELECT name,yearid, wswin,
			RANK() OVER(PARTITION BY yearid ORDER BY w DESC) AS season_rank
		FROM teams
		WHERE yearid BETWEEN 1970 AND 2016 AND yearid <> 1994)

	SELECT name, yearid, wswin, season_rank
	FROM team_wins
		WHERE season_rank = 1 AND wswin ='Y'
	ORDER BY yearid;

	-- What percentage of the time did the top team win the World Series?
	
	WITH team_wins AS(
		SELECT name,yearid, wswin,
			RANK() OVER(PARTITION BY yearid ORDER BY w DESC) AS season_rank
		FROM teams
			WHERE yearid BETWEEN 1970 AND 2016 AND yearid <> 1994),
	
	rank AS(
		SELECT name, yearid, wswin, season_rank
		FROM team_wins
			WHERE season_rank = 1
		ORDER BY yearid),

	seasons AS (
		SELECT COUNT(yearid) AS total_seasons,
			SUM(CASE WHEN wswin = 'Y' THEN 1 ELSE 0 END) AS ws_wins_by_top_team
 		 FROM rank)

	SELECT total_seasons,ws_wins_by_top_team,
		ROUND(100.0 * ws_wins_by_top_team / total_seasons, 2) AS win_percentage
	FROM seasons;
	
-- Q8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 average attendance per game in 2016 (where average attendance is defined as total attendance divided by number of games). Only consider parks where there were at least 10 games played. Report the park name, team name, and average attendance. Repeat for the lowest 5 average attendance.
	
	--Find the teams and parks which had the top 5 average attendance per game in 2016?
	
	SELECT park_name, t.name AS team_name, year,
		h.attendance AS total_attendance, games AS total_games,
		(h.attendance/games) AS avg_attendance_per_game
	FROM homegames AS h
		INNER JOIN parks AS p
			USING (park)
		INNER JOIN teams AS t
			ON h.team = t.teamid
		WHERE year = 2016 AND yearid = 2016 AND games >=10
	ORDER BY (h.attendance/games) DESC
	LIMIT 5;
	
	--Find the teams and parks which had the lowest 5 average attendance per game in 2016?
	
	SELECT park_name, t.name AS team_name, year,
		h.attendance AS total_attendance, games AS total_games,
		(h.attendance/games) AS avg_attendance_per_game
	FROM homegames AS h
		INNER JOIN parks AS p
			USING (park)
		INNER JOIN teams AS t
			ON h.team = t.teamid
		WHERE year = 2016 AND yearid = 2016 AND games >=10
	ORDER BY (h.attendance/games) ASC
	LIMIT 5;

-- Q9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

WITH TSN_winners AS (
    SELECT playerid, CONCAT(namefirst, ' ',namelast) AS full_name, awardid, lgid, yearid
    FROM awardsmanagers
    	INNER JOIN people 
			USING(playerid)
    WHERE awardid = 'TSN Manager of the Year' AND lgid IN ('AL', 'NL')),
	
multi_winners AS(
	SELECT playerid
	FROM TSN_winners
	GROUP BY playerid
		HAVING COUNT (DISTINCT lgid)=2)

SELECT DISTINCT tsn.playerid,full_name,
	tsn.yearid AS year_won, 
	t.name AS team_name,
	tsn.lgid AS league,
	awardid AS award_won
FROM TSN_winners AS tsn
	INNER JOIN multi_winners AS mw
		USING (playerid)
	INNER JOIN managers AS m
		ON tsn.playerid = m.playerid
		AND tsn.yearid = m.yearid
	INNER JOIN teams AS t
		ON tsn.yearid =t.yearid
		AND m.teamid =t.teamid;

-- Q10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

WITH hr_stats AS(
	SELECT namefirst,namelast,yearid,playerid, SUM(hr) AS total_hr
	FROM people
		INNER JOIN batting 
			USING (playerid)
	WHERE EXTRACT(YEAR FROM debut::date) <= 2006
	GROUP BY namefirst,namelast,yearid,playerid
	ORDER BY total_hr DESC NULLS LAST),

max_hr_stats AS(
	SELECT *,
		MAX(total_hr) OVER(PARTITION by playerid) AS career_high_hr_total
	FROM hr_stats)

	SELECT playerid, namefirst,namelast, yearid, total_hr AS hr_2016_total,career_high_hr_total
	FROM max_hr_stats
		WHERE yearid = 2016 AND total_hr >=1 AND career_high_hr_total <= total_hr
	ORDER BY total_hr DESC;

-- Q 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.

WITH rank_wins AS(
	SELECT yearid,name,teamid, SUM(w) AS total_season_wins,
		RANK()OVER(PARTITION BY yearid ORDER BY SUM(w)DESC) AS season_win_rank
	FROM teams
		WHERE yearid >=2000
	GROUP BY teamid,name,yearid),

salary_rank AS(
	SELECT yearid,teamid,SUM(salary)::numeric::money AS total_season_salary,
		RANK()OVER(PARTITION BY yearid ORDER BY SUM(salary)DESC) AS salary_season_rank
	FROM salaries
		WHERE yearid >=2000
	GROUP BY teamid,yearid)

SELECT  r.yearid,name,total_season_wins,season_win_rank,total_season_salary,salary_season_rank
FROM rank_wins AS r
	INNER JOIN salary_rank AS s
		ON r.teamid = s.teamid
		AND r.yearid = s.yearid
WHERE season_win_rank =1;

-- Q 12. In this question, you will explore the connection between number of wins and attendance.
	-- Does there appear to be any correlation between attendance at home games and number of wins?
	
	WITH rank_wins AS(
		SELECT yearid,name,teamid, SUM(w) AS total_season_wins,
			RANK()OVER(PARTITION BY yearid ORDER BY SUM(w)DESC) AS season_win_rank
		FROM teams
			WHERE yearid >=1995
		GROUP BY teamid,name,yearid),
	attendance_rank AS(
		SELECT yearid,teamid,SUM(attendance) AS total_season_attendance,
			RANK () OVER(PARTITION BY yearid ORDER BY SUM(attendance) DESC) AS season_attendance_rank
		FROM teams
			WHERE yearid >=1995
		GROUP BY teamid,name,yearid)
		
		SELECT  r.yearid,name,total_season_wins,season_win_rank,total_season_attendance,season_attendance_rank
		FROM rank_wins AS r
			INNER JOIN attendance_rank AS a
				ON r.teamid = a.teamid
				AND r.yearid = a.yearid
			WHERE season_win_rank =1;
			
	-- Do teams that win the world series see a boost in attendance the following year?
	
		SELECT t1.name AS team_name,
			t1.yearid AS year_won,
			t1.attendance AS attendance_winning_season,
			t2.yearid AS following_year,
			t2.attendance AS attendance_season_after,
			(t2.attendance - t1.attendance) AS attendance_diff_after_winning_season
		FROM teams as t1
			INNER JOIN teams AS t2
				ON t1.teamid=t2.teamid
				AND t2.yearid = t1.yearid +1
		WHERE t1.yearid >=1995 AND t1.wswin = 'Y';
		
	-- What about teams that made the playoffs?
	
		SELECT t1.name AS team_name,
			t1.yearid AS playoff_year,
			t1.attendance AS attendance_playoff_year,
			t2.yearid AS following_year,
			t2.attendance AS attendance_season_after,
			(t2.attendance - t1.attendance) AS attendance_diff_after_playoff_year
		FROM teams as t1
			INNER JOIN teams AS t2
				ON t1.teamid=t2.teamid
				AND t2.yearid = t1.yearid +1
		WHERE t1.yearid >=1995 AND (t1.wcwin = 'Y' OR t1.divwin = 'Y');

-- Q 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim.
	-- First, determine just how rare left-handed pitchers are compared with right-handed pitchers.
	
		SELECT throws,COUNT(DISTINCT playerid) AS player_count
		FROM pitching 
		INNER JOIN people 
			USING (playerid)
		WHERE throws ='L' OR throws = 'R'
		GROUP BY throws;

	--Are left-handed pitchers more likely to win the Cy Young Award?
	
		SELECT throws,COUNT(DISTINCT playerid) AS player_count,awardid
		FROM pitching
		INNER JOIN people 
			USING (playerid)
		INNER JOIN awardsplayers
			USING(playerid)
		WHERE awardid = 'Cy Young Award' AND (throws ='L' OR throws = 'R')
		GROUP BY throws,awardid;

	-- Are they more likely to make it into the hall of fame?

		SELECT throws,COUNT(DISTINCT playerid) AS player_count
		FROM pitching AS pi
			INNER JOIN people
				USING (playerid)
			INNER JOIN halloffame 
				USING (playerid)
		WHERE inducted = 'Y' AND (throws ='L' OR throws = 'R')
		GROUP BY throws;
	
	
