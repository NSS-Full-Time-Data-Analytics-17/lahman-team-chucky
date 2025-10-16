--1 date range of baseball games in the data 
SELECT
	MIN(yearid) AS first_year, 
	MAX(yearid) AS last_year
FROM teams;

---2 the shortest player and his team 
SELECT p.playerid, 
	p.namelast, 
	p.namefirst, 
	p.height,
	t.name
FROM people As p 
LEFT JOIN appearances AS c USING (playerid)
LEFT JOIN teams AS t USING (teamid, yearid)
ORDER BY height 
LIMIT 1;

--- 3 highest player who played for Vanderbilt and and earned to most money 
SELECT p.namefirst,
		p.namelast,
		s.schoolname,
		SUM(sa.salary)::numeric::money/3 AS total_salary
FROM schools AS s
	INNER JOIN collegeplaying AS c ON s.schoolid = c.schoolid
	INNER JOIN people AS p ON c.playerid = p.playerid
	INNER JOIN salaries AS sa ON p.playerid = sa.playerid
WHERE  s.schoolname = 'Vanderbilt University'
GROUP BY  p.namefirst,
		p.namelast,
		s.schoolname
LIMIT 1;

---4
WITH positions_table AS( 
SELECT yearid, po,
	CASE 
		WHEN pos = 'OF' THEN 'outfield'
		WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
		WHEN pos IN ('P', 'C') THEN 'Battery' ELSE 'No Pos'
		END AS positions_group
FROM fielding 
WHERE yearid = 2016
)

SELECT yearid,
	positions_group,
	SUM(po) AS total_po
FROM positions_table
GROUP BY yearid, positions_group; 

---6 the player with the most succesfull stealing bases in 2016 and the percent rate of sucess 
SELECT b.playerid, 
	p.namefirst, 
	p.namelast, 
	b.yearid,
	b.stint, 
	SUM(b.sb) AS total_steals,
	SUM(b.cs) AS caught_steals,
	ROUND(SUM(b.sb)::NUMERIC / SUM(b.sb + b.cs) * 100,2) AS success_rate_percent 
FROM batting AS b
INNER JOIN people AS p USING (playerid)
WHERE sb IS NOT NULL AND b.yearid = 2016
GROUP BY b.playerid, b.yearid, b.stint, p.namefirst, p.namelast 
HAVING SUM(b.sb + b.cs) >= 20
ORDER BY success_rate_percent DESC
LIMIT 1;

--7
FROM public.teams
WHERE yearid BETWEEN 1970 AND 2016
		AND wswin = 'N'
UNION 

SELECT MIN(w) AS max_wins_not_champion
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
 	AND wswin = 'Y'
	 AND yearid <> 1981yearid ASC, lgid ASC, teamid ASC 

	 
WITH wins_per_year AS (
	SELECT yearid, 
		MIN(w) AS max_wins_not_champion
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
	 AND yearid <> 1981
	GROUP BY yearid
)
 SELECT t.teamid, t.w,
	COUNT(*) AS year_team_max_wins_wseries,
	ROUND(COUNT(t.yearid::NUMERIC) / (2016 - 1970 +1 -1) *100, 2) AS percent
FROM wins_per_year AS w
INNER JOIN teams AS t 
	ON t.yearid = w.yearid 
	AND t.w = max_wins_not_champion
	AND  wswin = 'Y'
GROUP BY t.teamid, t.w;
--9
WITH manager_wins AS(
SELECT playerid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'NL'
	
INTERSECT

SELECT playerid
FROM awardsmanagers
WHERE awardid = 'TSN Manager of the Year'
	AND lgid = 'AL')
	
SELECT p.namefirst, p.namelast, a.lgid, t.name
FROM manager_wins AS m
	LEFT JOIN awardsmanagers AS a USING (playerid)
	LEFT JOIN people AS p USING (playerid)
	LEFT JOIN managers AS ms USING (playerid, yearid)
	LEFT JOIN teams AS t USING (yearid, teamid)
WHERE a.awardid = 'TSN Manager of the Year'
ORDER BY namelast
--- check this ^^^^ DUPLICATES 
-- 11. 

SELECT t.yearid, 
	t.teamid, 
	t.name,
	SUM(s.salary)::numeric AS total_salary,
	MIN(t.w)::numeric AS total_wins
FROM teams AS t 
	INNER JOIN salaries AS s USING (teamid,yearid)
WHERE yearid = 2000 
GROUP BY t.yearid, t.teamid, t.name
ORDER BY total_wins, total_salary DESC;



-- year by year analysis

WITH teams AS(
SELECT t.yearid, 
	t.teamid, 
	t.name,
	SUM(s.salary)::numeric AS total_salary,
	MIN(t.w)::numeric AS total_wins
FROM teams AS t 
	INNER JOIN salaries AS s USING (teamid,yearid)
WHERE yearid >= 2000 
GROUP BY t.yearid, t.teamid, t.name
ORDER BY total_wins, total_salary DESC
)
SELECT yearid, teamid,
	ROUND(AVG(total_salary))::money AS avg_salary,
	ROUND(AVG(total_wins), 2) AS avg_wins
FROM teams
GROUP BY yearid,teamid
ORDER BY yearid DESC;

-- 11

SELECT name, w, attendance  
FROM teams
WHERE attendance IS NOT NULL















