-- Q1. What range of years for baseball games played does the provided database cover? 

SELECT MIN(yearid) AS first_year, MAX(yearid) AS last_year
FROM batting;

-- Q2. Find the name and height of the shortest player in the database. How many games did he play in? What is the name of the team for which he played?

SELECT CONCAT(namefirst,' ',namelast) AS full_name,height,name AS team,g_all AS total_games_played
FROM people INNER JOIN appearances USING (playerid)
	  		INNER JOIN teams USING (teamid)
ORDER by height
LIMIT 1;

-- Q3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

WITH vandy_players AS(
	SELECT DISTINCT playerid,CONCAT(namefirst,' ',namelast) AS full_name
	FROM people INNER JOIN collegeplaying USING (playerid)
				INNER JOIN schools USING (schoolid)
	WHERE schoolname= 'Vanderbilt University')

SELECT full_name,SUM(salary)::numeric::money AS career_salary
FROM vandy_players INNER JOIN salaries USING (playerid)
GROUP BY full_name
ORDER BY career_salary DESC;
		
-- Q4. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.

WITH position_group AS(
	SELECT yearid,po,
		CASE WHEN POS = 'OF' THEN 'Outfield'
		 	 WHEN POS IN ('SS','1B','2B','3B') THEN 'Infield'
		 	 WHEN POS IN ('P','C') THEN 'Battery' END AS pos_group
	FROM fielding)
SELECT pos_group,yearid, SUM(po) AS total_po
FROM position_group
WHERE yearid = 2016
GROUP BY pos_group,yearid;

-- Q5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends?

SELECT CONCAT((yearid/10*10)::text, 's') AS decade,
	ROUND((SUM(hr)/(SUM(g)::numeric/2)),2) AS hr_per_game,
	ROUND((SUM(so)/(SUM(g)::numeric/2)),2) AS so_per_game
FROM teams
WHERE yearid >=1920
GROUP BY decade
ORDER BY decade

-- Q6.Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases.

SELECT CONCAT(namefirst,' ',namelast) AS full_name,ROUND(sb/(sb+cs::numeric)*100,2) AS sb_success_rate
FROM batting INNER JOIN people USING (playerid)
WHERE yearid = 2016 AND (cs+sb) >= 20
ORDER BY sb_success_rate DESC
LIMIT 1;

-- Q7. From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion – determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?

	-- From 1970 – 2016, what is the largest number of wins for a team that did not win the world series?
	
	SELECT yearid, name, SUM(w) AS total_wins
	FROM teams
		WHERE yearid BETWEEN 1970 AND 2016 AND wswin ='N'
	GROUP BY yearid,name
	ORDER BY total_wins DESC
	LIMIT 1;

	-- What is the smallest number of wins for a team that did win the world series? -- This was due to a shortend MLB season casued by a mid season strike.
	
	SELECT yearid, name, SUM(w) AS total_wins
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016 AND wswin ='Y'
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
	
	SELECT name, teams.park, homegames.attendance/homegames.games AS avg_attendance 
	FROM homegames INNER JOIN teams ON team=teamid AND year =yearid
	WHERE yearid = 2016 AND games >=10
	ORDER BY homegames.attendance DESC
	LIMIT 5;

	--Find the teams and parks which had the lowest 5 average attendance per game in 2016?
	
	SELECT name, teams.park, homegames.attendance/homegames.games AS avg_attendance
	FROM homegames INNER JOIN teams ON team=teamid AND year =yearid
	WHERE yearid = 2016 AND games >=10
	ORDER BY homegames.attendance ASC
	LIMIT 5;

-- Q9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.

SELECT CONCAT(namefirst,' ',namelast) AS full_name,name,awardid,awardsmanagers.lgid,yearid
FROM awardsmanagers INNER JOIN managers USING (playerid,yearid)
                    INNER JOIN people USING (playerid)
					INNER JOIN teams USING (teamid,yearid)
WHERE playerid IN (SELECT playerid
				   FROM awardsmanagers INNER JOIN managers USING (playerid,yearid)
				   WHERE awardid = 'TSN Manager of the Year' AND awardsmanagers.lgid IN ('AL','NL')
                   GROUP BY playerid
                   HAVING COUNT(DISTINCT awardsmanagers.lgid) = 2)
AND awardid = 'TSN Manager of the Year';

-- Q10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

WITH hr_stats AS(
	SELECT CONCAT(namefirst,' ',namelast) AS full_name,yearid,playerid, SUM(hr) AS total_hr
	FROM people INNER JOIN batting USING (playerid)
	WHERE EXTRACT(YEAR FROM debut::date) <= 2006
	GROUP BY full_name,yearid,playerid
	ORDER BY total_hr DESC NULLS LAST),
max_hr_stats AS(
	SELECT *,MAX(total_hr) OVER(PARTITION by playerid) AS career_high_hr_total
	FROM hr_stats)
	SELECT full_name, yearid, total_hr AS hr_2016_total,career_high_hr_total
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

SELECT  name,r.yearid,total_season_wins,season_win_rank,total_season_salary,salary_season_rank
FROM rank_wins AS r
	INNER JOIN salary_rank AS s
		ON r.teamid = s.teamid
		AND r.yearid = s.yearid
GROUP BY name,r.yearid,total_season_wins,season_win_rank,total_season_salary,salary_season_rank
ORDER BY name,r.yearid;

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
		
		SELECT name, r.yearid,total_season_wins,season_win_rank,total_season_attendance,season_attendance_rank	
		FROM rank_wins AS r
			INNER JOIN attendance_rank AS a
				ON r.teamid = a.teamid
				AND r.yearid = a.yearid
		GROUP BY name,r.yearid,total_season_wins,season_win_rank,total_season_attendance,season_attendance_rank
		ORDER BY name, r.yearid;
			
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
		WHERE inducted ='Y' AND (throws ='L' OR throws = 'R')
		GROUP BY throws;
	
	
