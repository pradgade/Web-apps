DROP PROCEDURE IF EXISTS p_spelling_reporting;

CREATE PROCEDURE p_spelling_reporting()
	COMMENT '-name-PG-name- -desc-for tableau views showing usage of web tools-desc-'
BEGIN
	-- Create an exit handler for when an error occurs in procedure
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
		BEGIN
			-- Get the error displayed
			GET DIAGNOSTICS CONDITION 1
				@sql_state = RETURNED_SQLSTATE,
				@errno = MYSQL_ERRNO,
				@errtxt = MESSAGE_TEXT;
-- Write the displayed error to the procedure_error_log table
			CALL analytics.p_error_logger('p_spelling_reporting');
-- Resignal previous error to db
			RESIGNAL;
		END;



### Create table of all possible career/country/month combinations
DROP TABLE if EXISTS analytics.country_career_all;
CREATE TABLE analytics.country_career_all
(
    KEY(country),
    KEY(career),
    KEY(MONTH)
)
SELECT
    country,
    career,
    a.month
FROM analytics.learner_logins ll
JOIN (SELECT DISTINCT LAST_DAY(ll.pupil_added) `month` FROM analytics.learner_logins ll) a
GROUP BY ll.country, ll.career, a.month
;


DROP TABLE if EXISTS analytics.country_pupils_a;
CREATE TABLE analytics.country_pupils_a
(
    KEY(country),
    KEY(MONTH)
)
SELECT
    country,
    COUNT(DISTINCT pupil_id) as pupils,
    LAST_DAY(ll.pupil_added) as month
from analytics.learner_logins ll
WHERE ll.user_active = 1
GROUP BY ll.country, LAST_DAY(ll.pupil_added)
;


### Use first table to ensure everything is accounted for every country
DROP TABLE if EXISTS analytics.country_pupils_b;
CREATE TABLE analytics.country_pupils_b
(
    KEY(country),
    KEY(MONTH)
)
SELECT
    a.country,
    a.month,
    IFNULL(b.pupils, 0) as pupils
from analytics.country_career_all a
LEFT JOIN analytics.country_pupils_a b ON b.country = a.country AND b.month = a.month
GROUP BY a.country, a.month
;


DROP TABLE if EXISTS analytics.country_pupils;
CREATE TABLE analytics.country_pupils
(
    KEY(country),
    KEY(MONTH)
)
SELECT
    a.country,
    a.month,
    SUM(b.pupils) as pupils
FROM analytics.country_pupils_b a
JOIN analytics.country_pupils_b b ON b.country = a.country AND b.month <= a.month
GROUP BY a.country, a.month
;


DROP TABLE if EXISTS analytics.career_pupils_a;
CREATE TABLE analytics.career_pupils_a
(
    KEY(career),
    KEY(MONTH)
)
SELECT
    career,
    COUNT(DISTINCT pupil_id) as pupils,
    LAST_DAY(ll.pupil_added) as month
from analytics.learner_logins ll
where ll.user_active = 1
GROUP BY ll.career, LAST_DAY(ll.pupil_added)
;

### Use first table to ensure everything is accounted for every career
DROP TABLE if EXISTS analytics.career_pupils_b;
CREATE TABLE analytics.career_pupils_b
(
    KEY(career),
    KEY(MONTH)
)
SELECT
    a.career,
    a.month,
    IFNULL(b.pupils, 0) as pupils
from analytics.country_career_all a
LEFT JOIN analytics.career_pupils_a b ON b.career = a.career AND b.month = a.month
GROUP BY a.career, a.month
;

DROP TABLE if EXISTS analytics.career_pupils;
CREATE TABLE analytics.career_pupils
(
    KEY(career),
    KEY(MONTH)
)
SELECT
    a.career,
    a.month,
    SUM(b.pupils) as pupils
FROM analytics.career_pupils_b a
JOIN analytics.career_pupils_b b ON b.career = a.career AND b.month <= a.month
GROUP BY a.career, a.month
;

DROP TABLE if EXISTS analytics.career_country_pupils_a;
CREATE TABLE analytics.career_country_pupils_a
(
    KEY(career),
    KEY(country),
    KEY(MONTH))
SELECT
    career,
    country,
    COUNT(DISTINCT pupil_id) as pupils,
    LAST_DAY(ll.pupil_added) as month
from analytics.learner_logins ll
where ll.user_active = 1
GROUP BY ll.country, ll.career, LAST_DAY(ll.pupil_added)
;

### Use first table to ensure everything is accounted for every country and career
DROP TABLE if EXISTS analytics.career_country_pupils_b;
CREATE TABLE analytics.career_country_pupils_b
(
    KEY(career),
    KEY(country),
    KEY(MONTH)
)
SELECT
    a.career,
    a.country,
    a.month,
    IFNULL(b.pupils, 0) as pupils
from analytics.country_career_all a
LEFT JOIN analytics.career_country_pupils_a b ON b.career = a.career AND b.country = a.country AND b.month = a.month
GROUP BY a.career, a.country, a.month
;

DROP TABLE if EXISTS analytics.career_country_pupils;
CREATE TABLE analytics.career_country_pupils
(
    KEY(career),
    KEY(country),
    KEY(MONTH)
)
SELECT
    a.career,
    a.country,
    a.month,
    SUM(b.pupils) as pupils
FROM analytics.career_country_pupils_b a
JOIN analytics.career_country_pupils_b b ON b.career = a.career AND b.country = a.country AND b.month <= a.month
GROUP BY a.career, a.country, a.month
;

### Now put everything together. Do in two stages for speed
### Country first
DROP TABLE if EXISTS analytics.country_career_all;
CREATE TABLE analytics.country_career_all
(
    KEY(career),
    KEY(country),
    KEY(MONTH))
SELECT
    a.MONTH,
    a.career,
    a.country,
    a.pupils as career_country_pupils,
    b.pupils as country_pupils
FROM analytics.career_country_pupils a
JOIN analytics.country_pupils b ON b.country = a.country AND b.month = a.month
;

### Then career. Return to this table later.
DROP TABLE if EXISTS analytics.country_career_all_a;
CREATE TABLE analytics.country_career_all_a
(
    KEY (career),
    KEY (country),
    KEY (month)
)
SELECT
    a.*,
    c.pupils as career_pupils
FROM analytics.country_career_all a
JOIN analytics.career_pupils c ON c.career = a.career AND c.month = a.month
;

DROP TABLE if EXISTS analytics.teacher_pupils_a;
CREATE TABLE analytics.teacher_pupils_a
(
    KEY(user_id),
    KEY(MONTH)
)
SELECT
    user_id,
    COUNT(DISTINCT pupil_id) as pupils,
    LAST_DAY(ll.pupil_added) as month
from analytics.learner_logins ll
where ll.user_active = 1
GROUP BY ll.user_id, LAST_DAY(ll.pupil_added)
;

DROP TABLE if EXISTS analytics.teacher_pupils;
CREATE TABLE analytics.teacher_pupils
(
    KEY(user_id),
    KEY(MONTH)
)
SELECT
    a.user_id,
    a.month,
    SUM(b.pupils) as pupils
FROM analytics.teacher_pupils_a a
JOIN analytics.teacher_pupils_a b ON b.user_id = a.user_id AND b.month <= a.month
GROUP BY a.user_id, a.month
;


### DROP ALL TABLES NO longer required
DROP TABLE if EXISTS analytics.teacher_pupils_a;
DROP TABLE if EXISTS analytics.country_pupils_a;
DROP TABLE if EXISTS analytics.career_pupils_a;
DROP TABLE if EXISTS analytics.career_country_pupils_a;
DROP TABLE if EXISTS analytics.teacher_pupils_a;
DROP TABLE if EXISTS analytics.country_pupils_b;
DROP TABLE if EXISTS analytics.career_pupils_b;
DROP TABLE if EXISTS analytics.career_country_pupils_b;
DROP TABLE if EXISTS analytics.teacher_pupils_b;
DROP TABLE if EXISTS analytics.country_career_all;

# The code below is edited by Pradnya, The insert statement with multiple Unions takes too long to execute.
#  Broke it  down into multiple inserts with a loop for the spelling one which iterates over every month since Jan 2022.


### make final tables
TRUNCATE analytics.spelling_reporting;

SET @ref_date := '2022-01-01';
SET @date_max = CURDATE();

		WHILE @ref_date < @date_max DO

			INSERT INTO analytics.spelling_reporting
			SELECT
					DATE(pp.created_at) as date,
					'Spelling' as app,
					pp.pupil_id,
					MIN(p.user_id) as teacher_id,
					count(pp.id) as plays,
					COUNT(DISTINCT pp.level_id) as levels_accessed,
					IF(SUM(pp.bronze_medal) + SUM(pp.silver_medal) + SUM(pp.gold_medal) > 0, 1, 0) as completed,
					car.category_type as career,
					co.country,
					tp.pupils as teacher_pupils,
					cop.pupils as country_pupils,
					cp.pupils as career_pupils,
					ccp.pupils as career_country_pupils
			FROM twinkl.twinkl_spelling_pupil_progress pp
			JOIN twinkl.twinkl_pupil p ON p.id = pp.pupil_id
			JOIN analytics.dx_user u ON u.user_id = p.user_id
			LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pp.created_at)
			JOIN twinkl.twinkl_career car ON car.id = u.career_id
			JOIN analytics.dx_country co ON co.country_id = u.country_id
			LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
			JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pp.created_at)
			JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pp.created_at)
			JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pp.created_at)
			WHERE st.id IS NULL
				AND pp.created_at >= @ref_date
        AND pp.created_at < @ref_date + INTERVAL 1 MONTH
			GROUP BY pp.pupil_id, DATE(pp.created_at);

			SET @ref_date := @ref_date + INTERVAL 1 MONTH;

    END WHILE;

# Inserting rows for puzzled and ESL web app
INSERT INTO analytics.spelling_reporting
SELECT
    DATE(pp.created_at) as date,
    'Puzzled' as app,
    pp.pupil_id,
    MIN(p.user_id) as teacher_id,
    count(pp.id) as plays,
    COUNT(DISTINCT pp.level_id) as levels_accessed,
    IF(SUM(pp.wordsearch) + SUM(pp.anagram) + SUM(pp.classic_jigsaw) + SUM(pp.word_matching) + SUM(strips_jigsaw) + SUM(sliding_tiles) +
    SUM(rotating_tiles) + SUM(switching_tiles) + SUM(puzzling_pairs) + SUM(through_the_binoculars) + SUM(shadow_matching) + SUM(pp.quiz) > 3, 1, 0) as completed,
    car.category_type as career,
    co.country,
    tp.pupils as teacher_pupils,
    cop.pupils as country_pupils,
    cp.pupils as career_pupils,
    ccp.pupils as career_country_pupils
FROM twinkl.twinkl_puzzled_pupil_progress pp
JOIN twinkl.twinkl_pupil p ON p.id = pp.pupil_id
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pp.created_at)
JOIN twinkl.twinkl_career car ON car.id = u.career_id
JOIN analytics.dx_country co ON co.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pp.created_at)
JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pp.created_at)
JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pp.created_at)
WHERE st.id IS NULL
GROUP BY pp.pupil_id, DATE(pp.created_at)

UNION

SELECT
    DATE(pp.created_at) as date,
    'ESL' as app,
    pp.pupil_id,
    MIN(p.user_id) as teacher_id,
    count(pp.id) as plays,
    COUNT(DISTINCT pp.lesson_id) as levels_accessed,
    IF(SUM(pp.through_the_binoculars) + SUM(pp.wordsearch) + SUM(pp.anagram) + SUM(pp.reaction) + SUM(pp.look_cover_write_check)
    + SUM(pp.matching) + SUM(pp.pairing) + SUM(pp.quiz) + SUM(pp.gap_fill) + SUM(pp.sentence_drag_and_drop) > 3, 1, 0) as completed,
    car.category_type as career,
    co.country,
    tp.pupils as teacher_pupils,
    cop.pupils as country_pupils,
    cp.pupils as career_pupils,
    ccp.pupils as career_country_pupils
FROM twinkl.twinkl_esl_pupil_progress pp
JOIN twinkl.twinkl_pupil p ON p.id = pp.pupil_id
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pp.created_at)
JOIN twinkl.twinkl_career car ON car.id = u.career_id
JOIN analytics.dx_country co ON co.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pp.created_at)
JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pp.created_at)
JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pp.created_at)
WHERE st.id IS NULL
GROUP BY pp.pupil_id, DATE(pp.created_at);

# Inserting rows for Learn and Go
INSERT INTO analytics.spelling_reporting
SELECT
    DATE(pd.datetime) as date,
    'Learn & Go' as app,
    pd.pupil_id,
    MIN(p.user_id) as teacher_id,
    count(DISTINCT pd.resource_id) as plays,
    null as levels_accessed,
    if( c.count >= 4, 1, 0) as completed,
    car.category_type as career,
    co.country,
    tp.pupils as teacher_pupils,
    cop.pupils as country_pupils,
    cp.pupils as career_pupils,
    ccp.pupils as career_country_pupils
FROM twinkl.twinkl_pupil_download_log pd
JOIN twinkl.twinkl_pupil p ON p.id = pd.pupil_id
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pd.datetime)
JOIN twinkl.twinkl_career car ON car.id = u.career_id
JOIN analytics.dx_country co ON co.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pd.datetime)
JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pd.datetime)
JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pd.datetime)
JOIN (SELECT d.pupil_id, count(DISTINCT d.resource_id) as count
      FROM twinkl.twinkl_pupil_download_log d
      GROUP BY d.session_id) c on pd.pupil_id = c.pupil_id
WHERE st.id IS NULL
AND pd.type_id = 2 #learn and go app only
GROUP BY pd.pupil_id, DATE(pd.datetime);

# Inserting rows for Lessons
INSERT INTO analytics.spelling_reporting
SELECT
    DATE(pd.datetime) as date,
    'Lessons' as app,
    pd.pupil_id,
    MIN(p.user_id) as teacher_id,
    count(DISTINCT pd.resource_id) as plays,
    null as levels_accessed,
    if( c.count >= 2, 1, 0) as completed,
    car.category_type as career,
    co.country,
    tp.pupils as teacher_pupils,
    cop.pupils as country_pupils,
    cp.pupils as career_pupils,
    ccp.pupils as career_country_pupils
FROM twinkl.twinkl_pupil_download_log pd
JOIN twinkl.twinkl_pupil p ON p.id = pd.pupil_id
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pd.datetime)
JOIN twinkl.twinkl_career car ON car.id = u.career_id
JOIN analytics.dx_country co ON co.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pd.datetime)
JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pd.datetime)
JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pd.datetime)
JOIN (SELECT d.pupil_id, count(DISTINCT d.resource_id) as count
      FROM twinkl.twinkl_pupil_download_log d
      GROUP BY d.session_id) c on pd.pupil_id = c.pupil_id
WHERE st.id IS NULL
AND pd.type_id = 1 #lessons area only
GROUP BY pd.pupil_id, DATE(pd.datetime);


# Inserting rows for Rhino readers web app
INSERT INTO analytics.spelling_reporting
SELECT
    DATE(pd.datetime) as date,
    'Rhino readers' as app,
    pd.pupil_id,
    MIN(p.user_id) as teacher_id,
    count(DISTINCT pd.resource_id) as plays,
    null as levels_accessed,
    if( c.count >= 2, 1, 0) as completed,
    car.category_type as career,
    co.country,
    tp.pupils as teacher_pupils,
    cop.pupils as country_pupils,
    cp.pupils as career_pupils,
    ccp.pupils as career_country_pupils
FROM twinkl.twinkl_pupil_download_log pd
JOIN twinkl.twinkl_pupil p ON p.id = pd.pupil_id
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN analytics.teacher_pupils tp ON tp.user_id = p.user_id AND tp.month = LAST_DAY(pd.datetime)
JOIN twinkl.twinkl_career car ON car.id = u.career_id
JOIN analytics.dx_country co ON co.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN analytics.career_pupils cp ON cp.career = car.category_type AND cp.month = LAST_DAY(pd.datetime)
JOIN analytics.country_pupils cop ON cop.country = co.country AND cop.month = LAST_DAY(pd.datetime)
JOIN analytics.career_country_pupils ccp ON ccp.country = co.country AND ccp.career = car.category_type AND ccp.month = LAST_DAY(pd.datetime)
JOIN (SELECT d.pupil_id, count(DISTINCT d.resource_id) as count
      FROM twinkl.twinkl_pupil_download_log d
      GROUP BY d.session_id) c on pd.pupil_id = c.pupil_id
WHERE st.id IS NULL
AND pd.type_id = 3 #Rhino readers
GROUP BY pd.pupil_id, DATE(pd.datetime);



INSERT INTO analytics.spelling_reporting
SELECT
     b.MONTH,
    'Spelling',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
     b.career,
     b.country,
    NULL,
     b.country_pupils,
     b.career_pupils,
     b.career_country_pupils
FROM analytics.country_career_all_a b
WHERE b.month > '2022-06-30'

UNION

SELECT
     b.MONTH,
    'Puzzled',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
     b.career,
     b.country,
    NULL,
     b.country_pupils,
     b.career_pupils,
     b.career_country_pupils
FROM analytics.country_career_all_a b
WHERE b.month > '2022-06-30'

UNION

SELECT
     b.MONTH,
    'ESL',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
     b.career,
     b.country,
    NULL,
     b.country_pupils,
     b.career_pupils,
     b.career_country_pupils
FROM analytics.country_career_all_a b
WHERE b.month > '2022-06-30'

UNION

SELECT
     b.MONTH,
    'Learn & Go',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
     b.career,
     b.country,
    NULL,
     b.country_pupils,
     b.career_pupils,
     b.career_country_pupils
FROM analytics.country_career_all_a b
WHERE b.month > '2022-06-30'

UNION

SELECT
     b.MONTH,
    'Lessons',
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
     b.career,
     b.country,
    NULL,
     b.country_pupils,
     b.career_pupils,
     b.career_country_pupils
FROM analytics.country_career_all_a b
WHERE b.month > '2022-06-30'
;


DROP TABLE if EXISTS analytics.teacher_pupils;
DROP TABLE if EXISTS analytics.country_pupils;
DROP TABLE if EXISTS analytics.career_pupils;
DROP TABLE if EXISTS analytics.career_country_pupils;
DROP TABLE if EXISTS analytics.country_career_all_a;


END;


CALL p_spelling_reporting();


create definer = lorna@`172.24.88.%` procedure p_learner_logins() comment '-name-LS-name- -desc-p_learner_logins-desc-'
BEGIN


# Create an exit handler for when an error occurs in procedure
DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
# Get the error displayed
    GET DIAGNOSTICS CONDITION 1
		@sql_state = RETURNED_SQLSTATE,
		@errno = MYSQL_ERRNO,
		@errtxt = MESSAGE_TEXT;
# Write the displayed error to the procedure_error_log table
	CALL analytics.p_error_logger('p_learner_logins');
# Resignal previous error to db
	RESIGNAL;
END;



#select all the pupils that have been added to a group
DROP TABLE IF EXISTS analytics.learner_logins_a;
CREATE TABLE analytics.learner_logins_a
(
    KEY(pupil_id)
)
SELECT
    p.user_id,
    u.date_created as `joined`,
    car.category_type as `career`,
    c.country as `country`,
    p.id as `pupil_id`,
    if(p.created_at = 0, p.updated_at, p.created_at) `pupil_added`,
    if(gp.pupil_id IS NULL, 0, 1) `added_to_group`,
    if(MAX(l.id) IS NULL, 0, 1) `created_lesson`,
    if(MAX(lr.id) IS NULL, 0, 1) `added_resource_to_lesson`,
    if(MAX(gl.id) IS NULL, 0, 1) `assigned_lesson_to_group`
FROM twinkl.twinkl_pupil p
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN twinkl.twinkl_career car ON car.id = u.career_id
LEFT JOIN analytics.dx_country c ON c.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
JOIN twinkl.twinkl_group_pupil gp ON gp.pupil_id = p.id
LEFT JOIN twinkl.twinkl_lesson l ON l.user_id = p.user_id
LEFT JOIN twinkl.twinkl_group_lesson gl ON gl.lesson_id = l.id
LEFT JOIN twinkl.twinkl_lesson_resource lr ON lr.lesson_id = l.id
WHERE st.id IS NULL
GROUP BY p.id, l.user_id
;

#insert the remaining pupils who had not been added to a group
INSERT INTO analytics.learner_logins_a
SELECT
    p.user_id,
    u.date_created as `joined`,
    car.category_type as `career`,
    c.country as `country`,
    p.id as `pupil_id`,
    if(p.created_at = 0, p.updated_at, p.created_at) as `pupil_added`,
    0 as `added_to_group`,
    if(MAX(l.id) IS NULL, 0, 1) as `created_lesson`,
    if(MAX(lr.id) IS NULL, 0, 1) as `added_resource_to_lesson`,
    if(MAX(gl.id) IS NULL, 0, 1) as `assigned_lesson_to_group`
FROM twinkl.twinkl_pupil p
JOIN analytics.dx_user u ON u.user_id = p.user_id
LEFT JOIN twinkl.twinkl_career car ON car.id = u.career_id
LEFT JOIN analytics.dx_country c ON c.country_id = u.country_id
LEFT JOIN twinkl.twinkl_staff st ON st.user_id = p.user_id
LEFT JOIN analytics.learner_logins_a ll ON ll.pupil_id = p.id
LEFT JOIN twinkl.twinkl_lesson l ON l.user_id = p.user_id
LEFT JOIN twinkl.twinkl_group_lesson gl ON gl.lesson_id = l.id
LEFT JOIN twinkl.twinkl_lesson_resource lr ON lr.lesson_id = l.id
WHERE st.id IS NULL
AND ll.pupil_id IS NULL
GROUP BY p.id
;


#create tables showing pupils who have accessed a lesson, spelling & puzzled
DROP TEMPORARY TABLE IF EXISTS analytics.lesson_access;
CREATE TEMPORARY TABLE analytics.lesson_access
(
    KEY(pupil_id)
)
SELECT
    pupil_id
FROM twinkl.twinkl_resource_tracking rt
WHERE rt.pupil_id IS NOT NULL
GROUP BY rt.pupil_id
;


DROP TEMPORARY TABLE IF EXISTS analytics.spelling_access;
CREATE TEMPORARY TABLE analytics.spelling_access
(
    KEY(pupil_id)
)
SELECT
    pupil_id
FROM twinkl.twinkl_spelling_pupil_progress spp
WHERE spp.pupil_id IS NOT NULL
GROUP BY spp.pupil_id
;


DROP TEMPORARY TABLE IF EXISTS analytics.puzzled_access;
CREATE TEMPORARY TABLE analytics.puzzled_access
(
    KEY(pupil_id)
)
SELECT
    pupil_id
FROM twinkl.twinkl_puzzled_pupil_progress ppp
WHERE ppp.pupil_id IS NOT NULL
GROUP BY ppp.pupil_id
;



#combine and create learner_logins table
DROP TABLE IF EXISTS analytics.learner_logins;
CREATE TABLE analytics.learner_logins
(
    KEY(pupil_id)
)
COMMENT = '-name-LS-name- -desc-Log of users creating pupils and lessons, and pupils then accessing lessons.-desc-'
SELECT
    l.*,
    CASE
        when s.user_id is not null then 1
        when s.user_id is null and w.user_id is not null and ss.school_id is null then 0
        when w.user_id is not null and ss.school_id is not null then 1
        when s.user_id is null and w.user_id is null and ss.school_id is null then 0
    end as user_active,
    if(la.pupil_id IS NULL, 0, 1) as pupil_accessed_lesson,
    if(sa.pupil_id IS NULL, 0, 1) as pupil_accessed_spelling,
    if(pa.pupil_id IS NULL, 0, 1) as pupil_accessed_puzzled
FROM analytics.learner_logins_a l
LEFT JOIN analytics.lesson_access la ON la.pupil_id = l.pupil_id
LEFT JOIN analytics.spelling_access sa ON sa.pupil_id = l.pupil_id
LEFT JOIN analytics.puzzled_access pa on pa.pupil_id = l.pupil_id
LEFT JOIN analytics.sub_ux_ind s on l.user_id = s.user_id and curdate() between s.ux_start_date and s.ux_end_date
LEFT JOIN analytics.will_school_user w on l.user_id = w.user_id and curdate() between w.start_date and ifnull(w.end_date,curdate())
LEFT JOIN analytics.sub_ux_school ss on w.school_id = ss.school_id and curdate() between ss.ux_start_date and ss.ux_end_date
ORDER BY l.user_id, l.pupil_id
;

DROP TABLE IF EXISTS analytics.learner_logins_a;


END;

