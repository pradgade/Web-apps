DROP PROCEDURE IF EXISTS p_spelling_engagement;

CREATE PROCEDURE p_spelling_engagement()
	COMMENT '-name-PG-name--desc-For looking at user engagement with the spelling web app-desc-'
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
			CALL analytics.p_error_logger('p_spelling_engagement');
-- Resignal previous error to db
			RESIGNAL;
		END;


	-- Levels accessed
	DROP TABLE IF EXISTS level_accessed;

	CREATE TABLE level_accessed
		(id INT,
		 pupil_id INT,
		 created_date DATETIME,
		 updated_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 reference VARCHAR(20),
		 reference_display VARCHAR(20),
		 gem_count INT,
		 star_count INT,
		 bronze_medal INT,
		 silver_medal INT,
		 gold_medal INT,
		 KEY (level_id))
		COMMENT '-name-PG-name- -desc-Staging table for spelling engagement-desc-'
	SELECT tspp.id,
				 tspp.pupil_id,
				 tspp.created_at AS created_date,
				 tspp.updated_at AS updated_date,
				 tspp.level_id,
				 tsl.name AS level_name,
				 tsl.reference,
				 tsl.reference_display,
				 tspp.gem_count,
				 tspp.star_count,
				 tspp.bronze_medal,
				 tspp.silver_medal,
				 tspp.gold_medal
	FROM twinkl.twinkl_spelling_pupil_progress AS tspp
		LEFT JOIN twinkl.twinkl_spelling_level AS tsl
			ON tspp.level_id = tsl.id;

-- Create a new table with the desired structure and attaching world info

	DROP TEMPORARY TABLE IF EXISTS new_spellings;

	CREATE TEMPORARY TABLE new_spellings
		(KEY (pupil_id))
	SELECT la.id,
				 la.pupil_id,
				 created_date AS played_date,
				 la.level_id,
				 level_name,
				 reference,
				 reference_display,
				 tsw.name AS world_name,
				 gem_count,
				 star_count,
				 bronze_medal,
				 silver_medal,
				 gold_medal
	FROM level_accessed AS la
		LEFT JOIN twinkl.twinkl_spelling_world_level AS tswl
			ON la.level_id = tswl.level_id
		LEFT JOIN twinkl.twinkl_spelling_world AS tsw
			ON tswl.world_id = tsw.id
	WHERE updated_date IS NULL


	UNION ALL

	SELECT la.id,
				 la.pupil_id,
				 la.updated_date AS played_date,
				 la.level_id,
				 level_name,
				 reference,
				 reference_display,
				 tsw.name AS world_name,
				 gem_count,
				 star_count,
				 bronze_medal,
				 silver_medal,
				 gold_medal
	FROM level_accessed AS la
		LEFT JOIN twinkl.twinkl_spelling_world_level AS tswl
			ON la.level_id = tswl.level_id
		LEFT JOIN twinkl.twinkl_spelling_world AS tsw
			ON tswl.world_id = tsw.id
	WHERE updated_date IS NOT NULL;

-- Adding teacher info such as career, country

	DROP TEMPORARY TABLE IF EXISTS spellings_engag;

	CREATE TEMPORARY TABLE spellings_engag
		(KEY (user_id))
	SELECT ns.id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 reference,
				 reference_display,
				 world_name,
				 p.user_id AS user_id,
				 car.category_type AS `career`,
				 c.country AS `country`,
				 gem_count,
				 star_count,
				 bronze_medal,
				 silver_medal,
				 gold_medal
	FROM new_spellings ns
		LEFT JOIN twinkl.twinkl_pupil AS p
			ON ns.pupil_id = p.id
		LEFT JOIN analytics.dx_user u
			ON u.user_id = p.user_id
		LEFT JOIN twinkl.twinkl_career car
			ON car.id = u.career_id
		LEFT JOIN analytics.dx_country c
			ON c.country_id = u.country_id;


-- Creating temporary table to access bundle_id from sub_ux

	DROP TABLE IF EXISTS bundle_spelling;

	CREATE TABLE bundle_spelling
		(user_id INT,
		 start_date DATETIME,
		 bundle_id INT,
		 bundle_name VARCHAR(20),
		 KEY (user_id))
		COMMENT '-name-PG-name- -desc-Staging table for spelling engagement-desc-'
	SELECT se.user_id,
				 suif.start_date,
				 suif.bundle_id,
				 db.bundle_name
	FROM spellings_engag AS se
		LEFT JOIN sub_ux_ind_flow AS suif
			ON se.user_id = suif.user_id
		LEFT JOIN dx_bundle AS db
			ON suif.bundle_id = db.id;

	DROP TEMPORARY TABLE IF EXISTS updated_bundle;

	CREATE TEMPORARY TABLE updated_bundle
		(KEY (user_id))
	SELECT DISTINCT b.user_id,
									b.bundle_id,
									b.bundle_name,
									b.start_date
	FROM bundle_spelling b
		JOIN (
					 SELECT user_id,
									MAX(start_date) AS latest_start_date
					 FROM bundle_spelling
					 GROUP BY user_id
				 ) latest_dates
			ON b.user_id = latest_dates.user_id AND b.start_date = latest_dates.latest_start_date;


-- Adding bundle to the table

	DROP TABLE IF EXISTS spellings_engagement_pre;

	CREATE TABLE spellings_engagement_pre
		(id INT,
		 pupil_id INT,
		 played_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 reference VARCHAR(20),
		 reference_display VARCHAR(20),
		 world_name VARCHAR(20),
		 user_id INT,
		 career VARCHAR(20),
		 country VARCHAR(20),
		 bundle_name VARCHAR(20),
		 gem_count INT,
		 star_count INT,
		 bronze_medal INT,
		 silver_medal INT,
		 gold_medal INT,
		 KEY (pupil_id))
		COMMENT '-name-PG-name- -desc-Staging table for spelling engagement-desc-'
	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 reference,
				 reference_display,
				 world_name,
				 se.user_id,
				 career,
				 country,
				 ub.bundle_name,
				 gem_count,
				 star_count,
				 bronze_medal,
				 silver_medal,
				 gold_medal
	FROM spellings_engag AS se
		LEFT JOIN updated_bundle AS ub
			ON se.user_id = ub.user_id;


	-- Pivoting the table to get gems/stars collected by each pupil

/*	DROP TABLE IF EXISTS spelling_engagement;

	CREATE TABLE spelling_engagement
		(id INT,
		 pupil_id INT,
		 played_date DATETIME,
		 level_id INT,
		 level_name VARCHAR(20),
		 reference VARCHAR(20),
		 reference_display VARCHAR(20),
		 world_name VARCHAR(20),
		 user_id INT,
		 career VARCHAR(20),
		 country VARCHAR(20),
		 bundle_name VARCHAR(20),
		 reward VARCHAR(20),
		 reward_count INT,
		 medal VARCHAR(20),
		 KEY (pupil_id))
		COMMENT '-name-PG-name- -desc-For looking at user engagement with the spelling web app-desc- -dim-App product-dim- -gdpr-No issue-gdpr- -type-type-'
*/
	-- Pivoting the table to get gems/stars collected by each pupil

	TRUNCATE analytics.spelling_engagement;
	INSERT INTO analytics.spelling_engagement
	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 reference,
				 reference_display,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'gem' AS reward,
				 gem_count AS reward_count,
				 CASE
					 WHEN bronze_medal = 1
						 THEN 'bronze'
					 WHEN silver_medal = 1
						 THEN 'silver'
					 WHEN gold_medal = 1
						 THEN 'gold'
					 ELSE NULL
				 END AS medal
	FROM spellings_engagement_pre

	UNION ALL

	SELECT id,
				 pupil_id,
				 played_date,
				 level_id,
				 level_name,
				 reference,
				 reference_display,
				 world_name,
				 user_id,
				 career,
				 country,
				 bundle_name,
				 'star' AS reward,
				 star_count AS reward_count,
				 CASE
					 WHEN bronze_medal = 1
						 THEN 'bronze'
					 WHEN silver_medal = 1
						 THEN 'silver'
					 WHEN gold_medal = 1
						 THEN 'gold'
					 ELSE NULL
				 END AS medal
	FROM spellings_engagement_pre;

	-- Dropping unnecessary tables
	DROP TABLE IF EXISTS level_accessed;
	DROP TABLE IF EXISTS spelling_world_accessed;
	DROP TEMPORARY TABLE IF EXISTS new_spellings;
	DROP TABLE IF EXISTS spelling_world_accessed;
	DROP TEMPORARY TABLE IF EXISTS spellings_engag;
	DROP TABLE IF EXISTS bundle_spelling;
	DROP TEMPORARY TABLE IF EXISTS updated_bundle;
	DROP TABLE IF EXISTS spellings_engagement_pre;

END;

CALL `p_spelling_engagement`();

-- Event code
/*
CREATE EVENT IF NOT EXISTS analytics.e_spelling_engagement
	ON SCHEDULE
		EVERY 1 DAY
			STARTS CURRENT_TIMESTAMP
	ON COMPLETION PRESERVE
	DISABLE -- ENABLE
	COMMENT '-name-PG-name-'
	DO
	BEGIN
		--
		CALL `analytics_procedure_logging_start`('e_spelling_engagement');
		--
		CALL `p_spelling_engagement`();
		--
		CALL `analytics_procedure_logging_stop`('e_spelling_engagement');
		--
	END;*/