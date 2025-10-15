
-- 1. What range of years for baseball games played does the provided database cover? 

SELECT MIN(yearid) AS first_year, MAX(yearid) AS latest_year
FROM teams
; -- 1871 - 2016


-- 2. Find the name and height of the shortest player in the database. How many games did he play in? What is the name of the team for which he played?

SELECT namefirst, namelast, height, g_all AS games_played, name
FROM people INNER JOIN appearances USING(playerid)
			INNER JOIN teams USING(teamid, yearid)
WHERE height = 
	(SELECT MIN(height) FROM people)
; -- Eddie Gaedel is the shortest player in the database at 43" tall.  He played one game, with the St. Louis Browns



-- 3. Find all players in the database who played at Vanderbilt University. Create a list showing each player’s first and last names as well as the total salary they earned in the major leagues. 
	-- Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?

SELECT namefirst, namelast, SUM(salary)::numeric::money AS total_salary
FROM people LEFT JOIN salaries USING(playerid)
WHERE playerid IN
	(SELECT playerid FROM collegeplaying WHERE schoolid = 
		(SELECT schoolid FROM schools WHERE schoolname = 'Vanderbilt University')
	)
GROUP BY namefirst, namelast
ORDER BY total_salary DESC NULLS LAST
; -- Of Vanderbilt alumni, David Price made the most money in the major leagues, with total earnings of almost $82M


/* 4. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with 
	position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". 
	Determine the number of putouts made by each of these three groups in 2016. */

SELECT pos_group, SUM(po) AS total_po
FROM
	(SELECT
		CASE WHEN pos = 'OF' THEN 'Outfield'
			 WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
			 WHEN pos IN ('P', 'C') THEN 'Battery'
			 ELSE NULL END AS pos_group, 
		po
	FROM fielding
	WHERE yearid = 2016)
GROUP BY pos_group
ORDER BY total_po DESC
;


-- 5. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. 
	-- Do the same for home runs per game. Do you see any trends?

SELECT CONCAT(LEFT(yearid::text, LENGTH(yearid::text)-1), '0s') AS decade, 
	ROUND((SUM(SO)::numeric/SUM(g)::numeric),2) AS SO_per_game,
	ROUND((SUM(HR)::numeric/SUM(g)::numeric), 2) AS HR_per_game
FROM teams
WHERE yearid >= 1920
GROUP BY CONCAT(LEFT(yearid::text, LENGTH(yearid::text)-1), '0s')
ORDER BY decade ASC
; --The number of both strikeouts and home runs per game have been steadily rising since the 1920s


-- 6. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. 
	-- (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases.

SELECT namefirst, namelast, (SUM(sb)*100)/(SUM(sb)+SUM(cs)) AS perc_steal_success
FROM batting LEFT JOIN people USING(playerid)
WHERE yearid = 2016
GROUP BY namefirst, namelast 
	HAVING (SUM(sb) + SUM(cs)) >= 20
ORDER BY perc_steal_success DESC NULLS LAST
LIMIT 1
; -- Chris Owings had the highest rate of successful base stealing, with 91% of his attemps resulting in a stolen base


/* 7.  From 1970 – 2016, what is the largest number of wins for a team that did not win the world series? 
	What is the smallest number of wins for a team that did win the world series? 
		Doing this will probably result in an unusually small number of wins for a world series champion – determine why this is the case. 
		Then redo your query, excluding the problem year. 
	How often from 1970 – 2016 was it the case that a team with the most wins also won the world series? What percentage of the time? */

(SELECT 'Most wins w/o WS' AS role, yearid, name, w
FROM teams
WHERE yearID BETWEEN 1970 AND 2016
	AND wswin = 'N'
ORDER BY w DESC NULLS LAST
LIMIT 1)

UNION ALL

(SELECT 'Fewest wins w/WS' AS role, yearid, name, w
FROM teams
WHERE yearID BETWEEN 1970 AND 2016
	AND wswin = 'Y'
ORDER BY w ASC
LIMIT 1)
; --The Seattle Mariners had the most wins for a year they did not win the world series during that period, with 116 wins in 2001
-- The LA Dodgers had only 63 wins when they won the world series in 1981 due to a players' strike that caused a two-month break in regular season games.


(SELECT 'Most wins w/o WS' AS role, yearid, name, w
FROM teams
WHERE yearID BETWEEN 1970 AND 2016
	AND wswin = 'N'
ORDER BY w DESC NULLS LAST
LIMIT 1)

UNION ALL

(SELECT 'Fewest wins w/WS' AS role, yearid, name, w
FROM teams
WHERE yearID BETWEEN 1970 AND 2016
	AND wswin = 'Y'
	AND yearID <> 1981
ORDER BY w ASC
LIMIT 1)
; -- Excluding 1981, the fewest wins for a WS champion was the St. Louis Cardinals, with 83 wins in 2006


SELECT 
	ROUND(
		(COUNT(yearid)::numeric/ -- the count of WS winners who won the most games that season
			(SELECT COUNT(*) -- the count of all WS games (indicated by presence of a winner) for the time period
			FROM teams
			WHERE yearID BETWEEN 1970 AND 2016
				AND wswin = 'Y')
		) * 100, 2
	) AS perc_wins_with_max
FROM teams AS t1
WHERE yearID BETWEEN 1970 AND 2016
	AND wswin = 'Y'
	AND w =	(SELECT MAX(w) FROM teams AS t2 WHERE t2.yearid = t1.yearid) -- where the team's wins that year are equal to the max wins of any team that year
; -- For the given period, the world series winner had the most number of wins in the season (or tied for most) 26% of the time.


/* 8. Using the attendance figures from the homegames table, find the teams and parks which had the top 5 average attendance per game in 2016 
	(where average attendance is defined as total attendance divided by number of games). Only consider parks where there were at least 10 games played. 
	Report the park name, team name, and average attendance. Repeat for the lowest 5 average attendance.
*/

--Highest attendance per game:
SELECT park_name, teams.name, h.attendance/h.games AS att_per_game
FROM homegames AS h LEFT JOIN teams ON h.team = teams.teamid
					LEFT JOIN parks ON h.park = parks.park
WHERE year = 2016
	AND games >= 10
	AND yearid = 2016
ORDER BY att_per_game DESC
LIMIT 5
;

--Lowest attendane per game: 
SELECT park_name, teams.name, h.attendance/h.games AS att_per_game
FROM homegames AS h LEFT JOIN teams ON h.team = teams.teamid
					LEFT JOIN parks ON h.park = parks.park
WHERE year = 2016
	AND games >= 10
	AND yearid = 2016
ORDER BY att_per_game ASC
LIMIT 5
;


-- 9. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? 
	-- Give their full name and the teams that they were managing when they won the award.

WITH dual_winners AS
	(
	(SELECT playerid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
		AND lgid = 'AL')
	
	INTERSECT
	
	(SELECT playerid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
		AND lgid = 'NL')
	)

SELECT DISTINCT namefirst, namelast, a.lgid, name
FROM dual_winners LEFT JOIN awardsmanagers AS a USING(playerid)
				  LEFT JOIN people USING(playerid)
				  LEFT JOIN managers USING(playerid, yearid)
				  LEFT JOIN teams USING(teamid, yearid)
WHERE awardid = 'TSN Manager of the Year'
ORDER BY namelast
;


-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, 
	-- and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.

SELECT playerid, namefirst, namelast, hr AS hr_2016
FROM batting AS b1 
	LEFT JOIN 
		(SELECT playerid, COUNT(DISTINCT yearid) AS career_years
			FROM appearances
			GROUP BY playerid
		)
		USING(playerid)
	LEFT JOIN people USING(playerid)
WHERE yearid = 2016
	AND hr = (SELECT MAX(hr) FROM batting AS b2 WHERE b2.playerid = b1.playerid)
	AND hr >= 1
	AND career_years >= 10
ORDER BY hr_2016 DESC
;
