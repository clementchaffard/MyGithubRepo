
-- Utility: list all indexes not created by the system (i.e., our custom indexes):
SELECT * FROM DBA_IND_COLUMNS WHERE TABLE_OWNER = 'C##DB2021_G41'
                                AND INDEX_NAME NOT LIKE 'SYS%'
                                AND INDEX_NAME NOT LIKE 'BIN%';

-- Utility: display query plan, right after running "EXPLAIN PLAN FOR <query>"
SELECT * FROM TABLE ( DBMS_XPLAN.DISPLAY );
-- Display short format of plan
SELECT * FROM TABLE ( DBMS_XPLAN.display('plan_table',null,'basic') );


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 1
-- --------------------------------------------------------------------------------------------

EXPLAIN PLAN FOR
SELECT CASE
         WHEN party_age <= 18 THEN '1-18'
         WHEN party_age <= 21 THEN '19-21'
         WHEN party_age <= 24 THEN '21-24'
         WHEN party_age <= 60 THEN '24-60'
         WHEN party_age <= 64 THEN '60-64'
         ELSE '64+'
       END AS age,
       COUNT(*)/(SELECT COUNT(*) FROM Party) AS ratio
FROM Party
WHERE PARTY_AGE IS NOT NULL
GROUP BY CASE
         WHEN party_age <= 18 THEN '1-18'
         WHEN party_age <= 21 THEN '19-21'
         WHEN party_age <= 24 THEN '21-24'
         WHEN party_age <= 60 THEN '24-60'
         WHEN party_age <= 64 THEN '60-64'
         ELSE '64+'
        END;


CREATE INDEX IDX_PARTYAGE ON PARTY(PARTY_AGE);


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 2
-- --------------------------------------------------------------------------------------------


EXPLAIN PLAN FOR
SELECT STATEWIDE_VEHICLE_TYPE AS TYPE, COUNT(*) AS COUNTS
FROM VEHICLE
WHERE STATEWIDE_VEHICLE_TYPE IS NOT NULL
      AND PID IN (
        -- Select parties involved in collisions with holes
        SELECT P.PID FROM PARTY P, ROADCONDITION R
        WHERE P.CASE_ID = R.CASE_ID AND
              R.ROAD_COND LIKE 'hole%'
)
GROUP BY STATEWIDE_VEHICLE_TYPE
ORDER BY COUNTS DESC
FETCH FIRST 5 ROWS ONLY;


CREATE INDEX IDX_VTYPE ON VEHICLE(STATEWIDE_VEHICLE_TYPE);
CREATE INDEX IDX_PARTY_CASEID ON PARTY(CASE_ID);


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 3
-- --------------------------------------------------------------------------------------------

SELECT v.vehicle_make, SUM(t.count_vic) as sum_vic
FROM (SELECT pid, COUNT(*) as count_vic
    FROM Victim
    WHERE degree_of_injury IN ('severe injury', 'killed')
    GROUP BY pid) t, vehicle v
WHERE t.pid = v.pid and v.vehicle_make IS NOT NULL
GROUP BY v.vehicle_make
ORDER BY sum_vic DESC
FETCH FIRST 10 ROWS ONLY;

-- the attribute degree_of_injury is missing


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 4
-- --------------------------------------------------------------------------------------------

SELECT victim_seating_position, COUNT(victim_seating_position)/(SELECT COUNT(victim_seating_position) FROM Victim) AS victim_per_seating_position_RATIO
FROM Victim
GROUP BY victim_seating_position
ORDER BY victim_per_seating_position_RATIO DESC;

CREATE INDEX IDX_VIC_SIT_POS ON VICTIM(victim_seating_position);


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 5
-- --------------------------------------------------------------------------------------------

EXPLAIN PLAN FOR
SELECT COUNT(*) FROM (
    -- Subquery: number of cities per vehicle type (at least 10 collisions per city)
    SELECT COUNT(DISTINCT CITY) as NCITY FROM (
        -- Subquery: vehicle type, city and number of collision in that city
        SELECT /*+ NO_INDEX(V IDX_PID_VTYPE) */ V.STATEWIDE_VEHICLE_TYPE as VTYPE,
               L.COUNTY_CITY_LOC AS CITY,
               COUNT(*) AS COUNTS
        FROM VEHICLE V, PARTY P, COLLISION C, LOCATION L
        -- Join vehicle and location
        WHERE V.PID = P.PID AND
              P.CASE_ID = C.CASE_ID AND
              C.LID = L.LID
        -- Aggregate
        GROUP BY V.STATEWIDE_VEHICLE_TYPE, L.COUNTY_CITY_LOC
    ) WHERE COUNTS >= 10
      GROUP BY VTYPE
) WHERE NCITY >= (SELECT COUNT(DISTINCT COUNTY_CITY_LOC) FROM LOCATION) / 2;


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 6
-- --------------------------------------------------------------------------------------------

SELECT city, population, case_id, mean_age
FROM
    (SELECT city, population, case_id, mean_age, row_number() OVER(PARTITION BY city ORDER BY mean_age ASC) as rn
        FROM (
            SELECT t2.city, t2.population, t.case_id, AVG(t.victim_age) OVER(PARTITION BY t.case_id) as mean_age
            FROM (
                SELECT p.case_id, v.victim_age
                FROM Party p, Victim v
                WHERE p.pid = v.pid and v.victim_age IS NOT NULL and v.victim_age > 0) t,
                Collision c,
                (SELECT l.county_city_loc as city, l.lid, l.population
                 FROM (SELECT DISTINCT(county_city_loc) as city, population
                       FROM Location
                       WHERE population IS NOT NULL and population < 9
                       ORDER BY population DESC
                       FETCH FIRST 3 ROWS ONLY) top, Location l
                WHERE l.county_city_loc = top.city) t2
        WHERE c.case_id = t.case_id and c.lid = t2.lid))
WHERE rn <= 10;

-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 7
-- --------------------------------------------------------------------------------------------

-- Collision of type pedestrian, all victims above 100 yo. Show collision id and age of oldest victim
EXPLAIN PLAN FOR
SELECT C.CASE_ID, X.MAXAGE
FROM COLLISION C, PARTY P, (
        SELECT V.PID, MAX(V.VICTIM_AGE) AS MAXAGE
        FROM VICTIM V
        WHERE V.VICTIM_AGE NOT IN (999, 998) 
        GROUP BY V.PID
        -- if min age of group is > 100, then all victims are > 100
        HAVING MIN(V.VICTIM_AGE) > 100
    ) X
WHERE C.TYPE_COLLISION = 'pedestrian' AND
      C.CASE_ID = P.CASE_ID AND
      P.PID IN X.PID;

CREATE INDEX IDX_VIC_PIDAGE ON VICTIM(PID, VICTIM_AGE);


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 8
-- --------------------------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT v.STATEWIDE_VEHICLE_TYPE, v.VEHICLE_MAKE, v.VEHICLE_YEAR, COUNT(p.case_id) AS number_collisions
FROM Party p, Vehicle v
WHERE (p.pid = v.pid
        and (
            v.STATEWIDE_VEHICLE_TYPE IS NOT NULL
            AND v.VEHICLE_MAKE IS NOT NULL
            AND v.VEHICLE_YEAR IS NOT NULL
            ))
GROUP BY v.STATEWIDE_VEHICLE_TYPE, v.VEHICLE_MAKE, v.VEHICLE_YEAR
HAVING COUNT(p.case_id) >= 10
ORDER BY number_collisions DESC;

SELECT V.VEHICLE_MAKE, COUNT(DISTINCT P.CASE_ID) as NCOLLISION
FROM VEHICLE V, PARTY P
WHERE V.PID = P.PID
GROUP BY V.VEHICLE_MAKE
HAVING COUNT(DISTINCT P.CASE_ID) >= 10
ORDER BY NCOLLISION DESC;


-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 9
-- --------------------------------------------------------------------------------------------

SELECT l.county_city_loc as city_location, COUNT(c.case_id) as number_collisions
FROM Location l, Collision c
WHERE c.lid = l.lid
GROUP BY l.county_city_loc
ORDER BY number_collisions DESC
FETCH FIRST 10 ROWS ONLY;

CREATE INDEX IDX_CCL ON Location(county_city_loc);

-- --------------------------------------------------------------------------------------------
-- --------------------- QUERY 10
-- --------------------------------------------------------------------------------------------
EXPLAIN PLAN FOR
SELECT CASE
         WHEN lighting LIKE '%day%' THEN 'daylight'
         WHEN lighting LIKE '%dark%' THEN 'night'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='06:00' AND TO_CHAR(datetime, 'HH24:MI')<='07:59' then 'dawn'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='18:00' AND TO_CHAR(datetime, 'HH24:MI')<='19:59' then 'dusk'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='04/01' AND TO_CHAR(datetime, 'mm/dd')<='08/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='04:00' AND TO_CHAR(datetime, 'HH24:MI')<='05:59' then 'dawn'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='20:00' AND TO_CHAR(datetime, 'HH24:MI')<='21:59' then 'dusk'
         ELSE 'Unknown'

        END AS lighting,
        COUNT(*)/(SELECT COUNT(*) FROM Collision) AS ratio
FROM Collision C, Conditions Cd
WHERE C.cid = Cd.cid
GROUP BY CASE
         WHEN lighting LIKE '%day%' THEN 'daylight'
         WHEN lighting LIKE '%dark%' THEN 'night'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='06:00' AND TO_CHAR(datetime, 'HH24:MI')<='07:59' then 'dawn'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='18:00' AND TO_CHAR(datetime, 'HH24:MI')<='19:59' then 'dusk'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='04/01' AND TO_CHAR(datetime, 'mm/dd')<='08/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='04:00' AND TO_CHAR(datetime, 'HH24:MI')<='05:59' then 'dawn'
         WHEN (TO_CHAR(datetime, 'mm/dd')>='09/01' OR TO_CHAR(datetime, 'mm/dd')<='03/31') AND
           TO_CHAR(datetime, 'HH24:MI')>='20:00' AND TO_CHAR(datetime, 'HH24:MI')<='21:59' then 'dusk'
         ELSE 'Unknown'
        END;

SELECT * FROM TABLE ( DBMS_XPLAN.display('plan_table',null,'basic') );

CREATE INDEX IDX_COL_CID ON COLLISION(CID);
CREATE INDEX IDX_light ON Conditions(lighting);
