-- Number of users
SELECT COUNT(DISTINCT user_id)
FROM twinkl.twinkl_pupil;

-- Number of pupils
SELECT COUNT(DISTINCT id)
FROM twinkl.twinkl_pupil;

-- Number of learners under each user with their careers
DROP TEMPORARY TABLE IF EXISTS user_pupil_count;

CREATE TEMPORARY TABLE user_pupil_count
SELECT tp.user_id,
			 COUNT(tp.id) AS pupil_count,
			 cco.neat_career_category AS career
FROM twinkl.twinkl_pupil AS tp
	JOIN analytics.dx_user AS du
		ON tp.user_id = du.user_id
	JOIN analytics.career_category_overview AS cco
		ON du.career_category_id = cco.id
WHERE created_at > '2023-09-01 00:00:00'
GROUP BY tp.user_id;

SELECT COUNT(*)
FROM user_pupil_count;


SELECT *
FROM user_pupil_count
WHERE user_id = 75021;

-- Number of users in each career for web apps
SELECT career,
			 COUNT(user_id) AS career_count
FROM user_pupil_count
GROUP BY career
ORDER BY career_count DESC;

SELECT career,
			 COUNT(DISTINCT user_id) AS career_count
FROM spelling_engagement
GROUP BY career
ORDER BY career_count DESC;

-- Librarians in all web apps
DROP TEMPORARY TABLE IF EXISTS lib_all;

CREATE TEMPORARY TABLE lib_all
SELECT DISTINCT(user_id) AS user_id,
							 career
FROM user_pupil_count
WHERE career = 'librarian';

-- Librarians in spellings app
DROP TEMPORARY TABLE IF EXISTS lib_sp;

CREATE TEMPORARY TABLE lib_sp
SELECT DISTINCT(user_id) AS user_id,
							 career
FROM spelling_engagement
WHERE career = 'librarian';

SELECT sp.user_id,
			 sp.career,
			 alld.user_id,
			 alld.career
FROM lib_sp AS sp
	LEFT JOIN lib_all AS alld
		ON sp.user_id = alld.user_id;


-- Number of users in each career for the website
SELECT cco.neat_career_category,
			 COUNT(cco.neat_career_category) AS career_count_website
FROM analytics.dx_user AS du
	JOIN analytics.career_category_overview AS cco
		ON du.career_category_id = cco.id
WHERE date_created > '2023-09-01 00:00:00'
GROUP BY cco.neat_career_category
ORDER BY career_count_website DESC;

SELECT career,
			 COUNT(DISTINCT user_id) AS count
FROM spelling_engagement
GROUP BY career
ORDER BY count DESC;


-- Creating temporary table to access bundle_id from sub_ux

DROP TABLE IF EXISTS bundle_puz;

CREATE TABLE bundle_puz
	(user_id INT,
	 start_date DATETIME,
	 bundle_id INT,
	 bundle_name VARCHAR(20),
	 KEY (user_id, start_date))
	COMMENT '-name-PG-name- -desc-Staging table for teacher-pupil ratio analysis-desc-'
SELECT upc.user_id,
			 suif.start_date,
			 suif.bundle_id,
			 db.bundle_name
FROM user_pupil_count AS upc
	LEFT JOIN sub_ux_ind_flow AS suif
		ON upc.user_id = suif.user_id
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

-- Adding bundle to the table and make final tables

DROP TEMPORARY TABLE IF EXISTS user_pupil_bundle_count;

CREATE TEMPORARY TABLE user_pupil_bundle_count
SELECT upc.user_id,
			 upc.pupil_count,
			 upc.career,
			 ub.bundle_name
FROM user_pupil_count AS upc
	LEFT JOIN updated_bundle AS ub
		ON upc.user_id = ub.user_id;

