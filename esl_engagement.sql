DROP PROCEDURE IF EXISTS p_esl_engagement;

CREATE PROCEDURE p_esl_engagement()
	COMMENT '-name-PG-name--desc-For looking at user engagement with the esl web app-desc-'
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
			CALL analytics.p_error_logger('p_esl_engagement');
-- Resignal previous error to db
			RESIGNAL;
		END;


	-- All active users for ESL with their lessons

	DROP TABLE IF EXISTS esl_lesson;

	CREATE TABLE esl_lesson
		(id INT,
		 pupil_id INT,
		 created_date DATETIME,
		 updated_date DATETIME,
		 lesson_id INT,
		 lesson_name VARCHAR(20),
		 through_the_binoculars INT,
		 wordsearch INT,
		 anagram INT,
		 reaction INT,
		 look_cover_write_check INT,
		 matching INT,
		 pairing INT,
		 quiz INT,
		 gap_fill INT,
		 sentence_drag_and_drop INT,
		 KEY (lesson_id))
		COMMENT '-name-PG-name- -desc-Staging table for esl web app engagement-desc-'
	SELECT tepp.id,
				 tepp.pupil_id,
				 tepp.created_at AS created_date,
				 tepp.updated_at AS updated_date,
				 tepp.lesson_id,
				 tel.lesson_name,
				 tepp.through_the_binoculars,
				 tepp.wordsearch,
				 tepp.anagram,
				 tepp.reaction,
				 tepp.look_cover_write_check,
				 tepp.matching,
				 tepp.pairing,
				 tepp.quiz,
				 tepp.gap_fill,
				 tepp.sentence_drag_and_drop
	FROM twinkl.twinkl_esl_pupil_progress AS tepp
		LEFT JOIN twinkl.twinkl_esl_lesson AS tel
			ON tepp.lesson_id = tel.id;

-- Create a new table with the desired structure
	DROP TEMPORARY TABLE IF EXISTS new_esl;

	CREATE TEMPORARY TABLE new_esl
		(KEY (pupil_id))
	SELECT el.id,
				 pupil_id,
				 created_date AS played_date,
				 el.lesson_id,
				 lesson_name,
				 level_name,
				 through_the_binoculars,
				 wordsearch,
				 anagram,
				 reaction,
				 look_cover_write_check,
				 matching,
				 pairing,
				 quiz,
				 gap_fill,
				 sentence_drag_and_drop
	FROM esl_lesson AS el
		LEFT JOIN twinkl.twinkl_esl_level_lesson AS tell
			ON el.lesson_id = tell.lesson_id
		LEFT JOIN twinkl.twinkl_esl_level AS tel
			ON tell.level_id = tel.id
	WHERE updated_date IS NULL

	UNION ALL

	SELECT el.id,
				 pupil_id,
				 updated_date AS played_date,
				 el.lesson_id,
				 lesson_name,
				 level_name,
				 through_the_binoculars,
				 wordsearch,
				 anagram,
				 reaction,
				 look_cover_write_check,
				 matching,
				 pairing,
				 quiz,
				 gap_fill,
				 sentence_drag_and_drop
	FROM esl_lesson AS el
		LEFT JOIN twinkl.twinkl_esl_level_lesson AS tell
			ON el.lesson_id = tell.lesson_id
		LEFT JOIN twinkl.twinkl_esl_level AS tel
			ON tell.level_id = tel.id
	WHERE updated_date IS NOT NULL;

-- Adding teacher info such as career, country

	DROP TEMPORARY TABLE IF EXISTS esl_engag;

	CREATE TEMPORARY TABLE esl_engag
		(KEY (pupil_id, user_id))
	SELECT ne.id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 p.user_id AS user_id,
				 car.category_type AS `career`,
				 c.country AS `country`,
				 through_the_binoculars,
				 wordsearch,
				 anagram,
				 reaction,
				 look_cover_write_check,
				 matching,
				 pairing,
				 quiz,
				 gap_fill,
				 sentence_drag_and_drop
	FROM new_esl AS ne
		LEFT JOIN twinkl.twinkl_pupil AS p
			ON ne.pupil_id = p.id
		LEFT JOIN analytics.dx_user u
			ON u.user_id = p.user_id
		LEFT JOIN twinkl.twinkl_career car
			ON car.id = u.career_id
		LEFT JOIN analytics.dx_country c
			ON c.country_id = u.country_id;

-- Creating temporary table to access bundle_id from sub_ux

	DROP TABLE IF EXISTS bundle_esl;

	CREATE TABLE bundle_esl
		(user_id INT,
		 start_date DATETIME,
		 bundle_id INT,
		 bundle_name VARCHAR(20),
		 KEY (user_id, start_date))
		COMMENT '-name-PG-name- -desc-Staging table for esl web app engagement-desc-'
	SELECT es.user_id,
				 suif.start_date,
				 suif.bundle_id,
				 db.bundle_name
	FROM esl_engag AS es
		LEFT JOIN sub_ux_ind_flow AS suif
			ON es.user_id = suif.user_id
		LEFT JOIN dx_bundle AS db
			ON suif.bundle_id = db.id;


	DROP TEMPORARY TABLE IF EXISTS updated_bundle;

	CREATE TEMPORARY TABLE updated_bundle
		(KEY (user_id))
	SELECT DISTINCT b.user_id,
									b.bundle_id,
									b.bundle_name,
									b.start_date
	FROM bundle_esl b
		JOIN (
					 SELECT user_id,
									MAX(start_date) AS latest_start_date
					 FROM bundle_esl
					 GROUP BY user_id
				 ) latest_dates
			ON b.user_id = latest_dates.user_id AND b.start_date = latest_dates.latest_start_date;

	DROP TABLE IF EXISTS bundle_esl;

-- Adding bundle to the table and make final tables
	DROP TABLE IF EXISTS esl_engagement_pre;

	CREATE TABLE esl_engagement_pre
		(id INT,
		 pupil_id INT,
		 played_date DATETIME,
		 lesson_id INT,
		 lesson_name VARCHAR(20),
		 level_name VARCHAR(20),
		 user_id INT,
		 career VARCHAR(20),
		 country VARCHAR(20),
		 bundle_name VARCHAR(20),
		 through_the_binoculars INT,
		 wordsearch INT,
		 anagram INT,
		 reaction INT,
		 look_cover_write_check INT,
		 matching INT,
		 pairing INT,
		 quiz INT,
		 gap_fill INT,
		 sentence_drag_and_drop INT,
		 KEY (pupil_id, user_id))
		COMMENT '-name-PG-name- -desc-Staging table for esl web app engagement-desc-'
	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 se.user_id,
				 career,
				 country,
				 ub.bundle_name,
				 through_the_binoculars,
				 wordsearch,
				 anagram,
				 reaction,
				 look_cover_write_check,
				 matching,
				 pairing,
				 quiz,
				 gap_fill,
				 sentence_drag_and_drop
	FROM esl_engag AS se
		LEFT JOIN updated_bundle AS ub
			ON se.user_id = ub.user_id;


	-- Pivoting the table to get games_played by each pupil
	-- DROP TABLE IF EXISTS esl_engagement;

	-- CREATE TABLE esl_engagement
	-- COMMENT '-name-PG-name- -desc-For looking at user engagement with the esl web app-desc- -dim-App product-dim- -gdpr-No issue-gdpr- -type-type-'
	TRUNCATE analytics.esl_engagement;

	INSERT INTO analytics.esl_engagement
	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'through_the_binoculars' AS game_played
	FROM esl_engagement_pre
	WHERE through_the_binoculars = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'wordsearch' AS game_played
	FROM esl_engagement_pre
	WHERE wordsearch = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'anagram' AS game_played
	FROM esl_engagement_pre
	WHERE anagram = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'reaction' AS game_played
	FROM esl_engagement_pre
	WHERE reaction = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'look_cover_write_check' AS game_played
	FROM esl_engagement_pre
	WHERE look_cover_write_check = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'matching' AS game_played
	FROM esl_engagement_pre
	WHERE matching = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'pairing' AS game_played
	FROM esl_engagement_pre
	WHERE pairing = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'quiz' AS game_played
	FROM esl_engagement_pre
	WHERE quiz = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'gap_fill' AS game_played
	FROM esl_engagement_pre
	WHERE gap_fill = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 lesson_id,
				 lesson_name,
				 level_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'sentence_drag_and_drop' AS game_played
	FROM esl_engagement_pre
	WHERE sentence_drag_and_drop = 1;


-- Dropping all the unnecessary tables

	DROP TEMPORARY TABLE IF EXISTS esl_lesson;
	DROP TABLE IF EXISTS esl_level;
	DROP TEMPORARY TABLE IF EXISTS new_esl;
	DROP TEMPORARY TABLE IF EXISTS esl_engag;
	DROP TABLE IF EXISTS bundle_esl;
	DROP TEMPORARY TABLE IF EXISTS updated_bundle;
	DROP TABLE IF EXISTS esl_engagement_pre;

END;

CALL p_esl_engagement();

-- Event code

/*CREATE EVENT IF NOT EXISTS analytics.e_esl_engagement
	ON SCHEDULE
		EVERY 1 DAY
			STARTS CURRENT_TIMESTAMP
	ON COMPLETION PRESERVE
	DISABLE -- ENABLE
	COMMENT '-name-PG-name-'
	DO
	BEGIN
		--
		CALL `analytics_procedure_logging_start`('e_esl_engagement');
		--
		CALL `p_esl_engagement`();
		--
		CALL `analytics_procedure_logging_stop`('e_esl_engagement');
		--
	END;*/