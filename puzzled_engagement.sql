DROP PROCEDURE IF EXISTS p_puzzled_engagement;

CREATE PROCEDURE p_puzzled_engagement()
	COMMENT '-name-PG-name--desc-For looking at user engagement with the puzzled web app-desc-'
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
			CALL analytics.p_error_logger('p_puzzled_engagement');
-- Resignal previous error to db
			RESIGNAL;
		END;


	-- All active users for Puzzled with their levels

	DROP TABLE IF EXISTS puzzled_level;

	CREATE TABLE puzzled_level
		(id INT,
		 pupil_id INT,
		 created_date DATETIME,
		 updated_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 wordsearch INT,
		 anagram INT,
		 classic_jigsaw INT,
		 word_matching INT,
		 strips_jigsaw INT,
		 sliding_tiles INT,
		 rotating_tiles INT,
		 switching_tiles INT,
		 puzzling_pairs INT,
		 through_the_binoculars INT,
		 quiz INT,
		 shadow_matching INT,
		 KEY (level_id))
		COMMENT '-name-PG-name- -desc-Staging table for puzzled web app engagement-desc-'
	SELECT tppp.id,
				 tppp.pupil_id,
				 tppp.created_at AS created_date,
				 tppp.updated_at AS updated_date,
				 tppp.level_id,
				 tpl.level_name,
				 tppp.wordsearch,
				 tppp.anagram,
				 tppp.classic_jigsaw,
				 tppp.word_matching,
				 tppp.strips_jigsaw,
				 tppp.sliding_tiles,
				 tppp.rotating_tiles,
				 tppp.switching_tiles,
				 tppp.puzzling_pairs,
				 tppp.through_the_binoculars,
				 tppp.quiz,
				 tppp.shadow_matching
	FROM twinkl.twinkl_puzzled_pupil_progress AS tppp
		LEFT JOIN twinkl.twinkl_puzzled_level AS tpl
			ON tppp.level_id = tpl.id;

-- Create a new table with the desired structure and attaching world info

	DROP TEMPORARY TABLE IF EXISTS new_puzzled;

	CREATE TEMPORARY TABLE new_puzzled
		(KEY (pupil_id))
	SELECT pl.id,
				 pupil_id,
				 created_date AS played_date,
				 pl.level_id,
				 pl.level_name,
				 tpw.world_name,
				 wordsearch,
				 anagram,
				 classic_jigsaw,
				 word_matching,
				 strips_jigsaw,
				 sliding_tiles,
				 rotating_tiles,
				 switching_tiles,
				 puzzling_pairs,
				 through_the_binoculars,
				 quiz,
				 shadow_matching
	FROM puzzled_level AS pl
		LEFT JOIN twinkl.twinkl_puzzled_world_level AS tpwl
			ON pl.level_id = tpwl.level_id
		LEFT JOIN twinkl.twinkl_puzzled_level AS tpl
			ON tpwl.level_id = tpl.id
		LEFT JOIN twinkl.twinkl_puzzled_world AS tpw
			ON tpwl.world_id = tpw.id
	WHERE updated_date IS NULL

	UNION ALL

	SELECT pl.id,
				 pupil_id,
				 updated_date AS played_date,
				 pl.level_id,
				 pl.level_name,
				 tpw.world_name,
				 wordsearch,
				 anagram,
				 classic_jigsaw,
				 word_matching,
				 strips_jigsaw,
				 sliding_tiles,
				 rotating_tiles,
				 switching_tiles,
				 puzzling_pairs,
				 through_the_binoculars,
				 quiz,
				 shadow_matching
	FROM puzzled_level AS pl
		LEFT JOIN twinkl.twinkl_puzzled_world_level AS tpwl
			ON pl.level_id = tpwl.level_id
		LEFT JOIN twinkl.twinkl_puzzled_level AS tpl
			ON tpwl.level_id = tpl.id
		LEFT JOIN twinkl.twinkl_puzzled_world AS tpw
			ON tpwl.world_id = tpw.id
	WHERE updated_date IS NOT NULL;

-- Adding teacher info such as career, country

	DROP TEMPORARY TABLE IF EXISTS puz_engag;

	CREATE TEMPORARY TABLE puz_engag
		(KEY (pupil_id, user_id))
	SELECT np.id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 p.user_id AS user_id,
				 car.category_type AS `career`,
				 c.country AS `country`,
				 wordsearch,
				 anagram,
				 classic_jigsaw,
				 word_matching,
				 strips_jigsaw,
				 sliding_tiles,
				 rotating_tiles,
				 switching_tiles,
				 puzzling_pairs,
				 through_the_binoculars,
				 quiz,
				 shadow_matching
	FROM new_puzzled AS np
		LEFT JOIN twinkl.twinkl_pupil AS p
			ON np.pupil_id = p.id
		LEFT JOIN analytics.dx_user u
			ON u.user_id = p.user_id
		LEFT JOIN twinkl.twinkl_career car
			ON car.id = u.career_id
		LEFT JOIN analytics.dx_country c
			ON c.country_id = u.country_id;

-- Creating temporary table to access bundle_id from sub_ux

	DROP TABLE IF EXISTS bundle_puz;

	CREATE TABLE bundle_puz
		(user_id INT,
		 start_date DATETIME,
		 bundle_id INT,
		 bundle_name VARCHAR(20),
		 KEY (user_id, start_date))
		COMMENT '-name-PG-name- -desc-Staging table for puzzled web app engagement-desc-'
	SELECT pe.user_id,
				 suif.start_date,
				 suif.bundle_id,
				 db.bundle_name
	FROM puz_engag AS pe
		LEFT JOIN sub_ux_ind_flow AS suif
			ON pe.user_id = suif.user_id
		LEFT JOIN dx_bundle AS db
			ON suif.bundle_id = db.id;


	DROP TEMPORARY TABLE IF EXISTS updated_bundle;

	CREATE TEMPORARY TABLE updated_bundle
		(KEY (user_id))
	SELECT DISTINCT b.user_id,
									b.bundle_id,
									b.bundle_name,
									b.start_date
	FROM bundle_puz b
		JOIN (
					 SELECT user_id,
									MAX(start_date) AS latest_start_date
					 FROM bundle_puz
					 GROUP BY user_id
				 ) latest_dates
			ON b.user_id = latest_dates.user_id AND b.start_date = latest_dates.latest_start_date;

	DROP TABLE IF EXISTS bundle_puz;

-- Adding bundle to the table and make final tables

	DROP TABLE IF EXISTS puz_engagement_pre;

	CREATE TABLE puz_engagement_pre
		(id INT,
		 pupil_id INT,
		 played_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 world_name VARCHAR(20),
		 user_id INT,
		 career VARCHAR(20),
		 country VARCHAR(20),
		 bundle_name VARCHAR(20),
		 wordsearch INT,
		 anagram INT,
		 classic_jigsaw INT,
		 word_matching INT,
		 strips_jigsaw INT,
		 sliding_tiles INT,
		 rotating_tiles INT,
		 switching_tiles INT,
		 puzzling_pairs INT,
		 through_the_binoculars INT,
		 quiz INT,
		 shadow_matching INT,
		 KEY (pupil_id, user_id))
		COMMENT '-name-PG-name- -desc-Staging table for Puzzled web app engagement-desc-'
	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 pe.user_id,
				 career,
				 country,
				 ub.bundle_name,
				 wordsearch,
				 anagram,
				 classic_jigsaw,
				 word_matching,
				 strips_jigsaw,
				 sliding_tiles,
				 rotating_tiles,
				 switching_tiles,
				 puzzling_pairs,
				 through_the_binoculars,
				 quiz,
				 shadow_matching
	FROM puz_engag AS pe
		LEFT JOIN updated_bundle AS ub
			ON pe.user_id = ub.user_id;


	-- Pivoting the table to get games_played by each pupil in a single column

	-- TRUNCATE analytics.esl_engagement;
	-- INSERT INTO analytics.puzzled_engagement
	DROP TABLE IF EXISTS puzzled_engagement;

	CREATE TABLE puzzled_engagement
		(id INT,
		 pupil_id INT,
		 played_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 world_name VARCHAR(20),
		 user_id INT,
		 career VARCHAR(20),
		 country VARCHAR(20),
		 bundle_name VARCHAR(20),
		 game_played VARCHAR(20),
		 KEY (pupil_id))
		COMMENT '-name-PG-name- -desc-For looking at user engagement with the puzzled web app-desc- -dim-App product-dim- -gdpr-No issue-gdpr- -type-type-'
	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'wordsearch' AS game_played
	FROM puz_engagement_pre
	WHERE wordsearch = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'anagram' AS game_played
	FROM puz_engagement_pre
	WHERE anagram = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'classic_jigsaw' AS game_played
	FROM puz_engagement_pre
	WHERE classic_jigsaw = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'word_matching' AS game_played
	FROM puz_engagement_pre
	WHERE word_matching = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'strips_jigsaw' AS game_played
	FROM puz_engagement_pre
	WHERE strips_jigsaw = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'sliding_tiles' AS game_played
	FROM puz_engagement_pre
	WHERE sliding_tiles = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'rotating_tiles' AS game_played
	FROM puz_engagement_pre
	WHERE rotating_tiles = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'switching_tiles' AS game_played
	FROM puz_engagement_pre
	WHERE switching_tiles = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'puzzling_pairs' AS game_played
	FROM puz_engagement_pre
	WHERE puzzling_pairs = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'through_the_binoculars' AS game_played
	FROM puz_engagement_pre
	WHERE through_the_binoculars = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'quiz' AS game_played
	FROM puz_engagement_pre
	WHERE quiz = 1

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'shadow_matching' AS game_played
	FROM puz_engagement_pre
	WHERE shadow_matching = 1;


-- Dropping all the unnecessary tables
	DROP TABLE IF EXISTS puzzled_level;
	DROP TEMPORARY TABLE IF EXISTS new_puzzled;
	DROP TEMPORARY TABLE IF EXISTS puz_engag;
	DROP TABLE IF EXISTS bundle_puz;
	DROP TABLE IF EXISTS puz_engagement_pre;


END;

CALL p_puzzled_engagement();

-- Event code

CREATE EVENT IF NOT EXISTS analytics.e_puzzled_engagement
	ON SCHEDULE
		EVERY 1 DAY
			STARTS CURRENT_TIMESTAMP
	ON COMPLETION PRESERVE
	DISABLE -- ENABLE
	COMMENT '-name-PG-name-'
	DO
	BEGIN
		--
		CALL `analytics_procedure_logging_start`('e_puzzled_engagement');
		--
		CALL `p_puzzled_engagement`();
		--
		CALL `analytics_procedure_logging_stop`('e_puzzled_engagement');
		--
	END;