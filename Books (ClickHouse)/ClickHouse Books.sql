-- топ-20 городов и регионов России по суммарному количеству прочитанных и прослушанных часов любого контента с мобильных устройств. 
SELECT
	usage_geo_id_name,
	round(SUM(hours)) AS total_hours,
	round(sumIf(hours, usage_platform_ru = 'Букмейт Android')) AS total_hours_android,
	round(sumIf(hours, usage_platform_ru = 'Букмейт iOS')) AS total_hours_ios
FROM
	source_db.audition AS a 
WHERE
	usage_country_name = 'Россия'
	AND usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
	AND usage_geo_id_name NOT LIKE '%федеральный%'
	AND usage_geo_id_name NOT IN ('Россия')
GROUP BY
	usage_geo_id_name
ORDER BY 
	total_hours DESC
LIMIT 20;



--  топ-5 книг по суммарному количеству прочитанных и прослушанных часов на мобильных платформах. 
SELECT
	c.main_content_name AS name_book,
	c.main_author_name AS name_author,
	round(SUM(a.hours), 2) AS total_hours,
	round(avgIf(a.hours, c.main_content_type = 'Book'), 2) AS avg_hours_book,
	round(avgIf(a.hours, c.main_content_type = 'Audiobook'), 2) AS avg_hours_audio
FROM
	source_db.audition AS a
LEFT JOIN
	source_db.content AS c USING(main_content_id)
WHERE
	usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
	AND c.main_content_type IN ('Book', 'Audiobook')
GROUP BY
	name_book, name_author
HAVING
	COUNT(DISTINCT c.main_content_type) = 2
ORDER BY
	total_hours DESC
LIMIT 5;


--топ-10 авторов по суммарной длительности чтения их книг на всех платформах
SELECT
	main_author_name,
	uniqExactIf(c.main_content_name, c.main_content_type = 'Book') AS cnt_books,
	avgIf(a.hours, a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android') AND c.main_content_type = 'Audiobook') AS avg_durings
FROM 
	source_db.content AS c
JOIN 
	source_db.audition AS a USING(main_content_id) 
WHERE
	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
GROUP BY 
	main_author_name
HAVING
	uniqIf(c.main_content_name, c.main_content_type = 'Audiobook') > 0
ORDER BY 
	sumIf(a.hours, c.main_content_type = 'Book') DESC
LIMIT 10;


-- популярность контента в разрезе платформ
WITH stas_users AS 
	(SELECT
		a.puid,
		a.usage_platform_ru AS platform,
		SUM(a.hours) AS total_hours,
		sumIf(a.hours, c.main_content_type = 'Book') AS total_hours_books,
		sumIf(a.hours, c.main_content_type = 'Audiobook') AS total_hours_audio
	FROM 
		source_db.audition AS a 
	LEFT JOIN 
		source_db.content AS c USING(main_content_id)
	WHERE 
		a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
		AND c.main_content_type IN ('Book', 'Audiobook')
	GROUP BY 
		a.puid, a.usage_platform_ru
	),
stats_withh_first_platform AS (
	SELECT
		puid,
		argMax(platform, total_hours) AS main_platform,
		SUM(total_hours) AS sum_hours,
		SUM(total_hours_books) AS books_sum_hours,
		SUM(total_hours_audio) AS audio_sum_hours
	FROM
		stas_users
	GROUP BY
		puid
),
segment_stats AS (
	SELECT
		puid,
		main_platform,
		sum_hours,
		books_sum_hours,
		audio_sum_hours,
		multiIf(audio_sum_hours / sum_hours >= 0.7, 'Слушатель',
				books_sum_hours / sum_hours >= 0.7, 'Читатель',
				'Оба') AS segmrnt
	FROM
		stats_withh_first_platform
	WHERE
		sum_hours > 0
		AND (books_sum_hours > 0 OR audio_sum_hours > 0)
)
SELECT
	main_platform,
	segmrnt,
	uniqExact(puid) AS uniq_cnt
FROM
	segment_stats
GROUP BY
	main_platform, segmrnt
ORDER BY
	main_platform, segmrnt DESC
	
	
-- Сезонность потребления контента в зависимости от дня недели
	WITH dayli_stats AS (
	SELECT
		--a.usage_platform_ru AS platform,
		c.main_content_type AS content,
		a.msk_business_dt_str AS date,
		toDayOfWeek(a.msk_business_dt_str) AS day_of_week,
		a.hours
	FROM
		source_db.audition AS a
	LEFT JOIN 
		source_db.content AS c ON a.main_content_id  = c.main_content_id
	WHERE
		a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
		AND c.main_content_type IN ('Book', 'Audiobook')
)
SELECT
	content,
	IF(day_of_week IN (6, 7), 'Выходные', 'Будни') AS day,
	round(AVG(hours), 2) AS avg_hours
FROM 
	dayli_stats
GROUP BY 
	content, day
ORDER BY
	content, day
	
	
SELECT
	c.main_content_type AS content,
	toDayOfWeek(a.msk_business_dt_str) AS dow,
	round(AVG(a.hours), 2) AS avg_hours
FROM
	source_db.audition AS a
LEFT JOIN 
	source_db.content AS c ON a.main_content_id  = c.main_content_id
WHERE
	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android', 'Букмейт Web')
	AND c.main_content_type IN ('Book', 'Audiobook')
GROUP BY 
	content, dow
ORDER BY 	
	content, dow	
	
	

-- Процент пользователей с последней версией приложения в разрезе мобильной ОС
WITH users_platform_vers AS(
SELECT
	puid,
	usage_platform_ru AS platform_user,
	argMax(app_version, msk_business_dt_str) AS user_vers
FROM
	source_db.audition AS a 
WHERE
	a.usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP BY
	puid, platform_user
),
pltform_vers AS (
SELECT
	usage_platform_ru AS platform,
	argMax(app_version, msk_business_dt_str) AS platform_ver
FROM 
	source_db.audition
WHERE
	usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
GROUP BY 
	platform
),
pre_tabel AS (
	SELECT
		*,
		IF(user_vers = platform_ver, 1, 0) AS marker_vers
	FROM
		users_platform_vers AS u
	LEFT JOIN 
		pltform_vers AS p ON u.platform_user = p.platform
)
SELECT
	platform,
	ROUND(AVG(marker_vers) * 100, 2) AS share_with_last_vers
FROM 
	pre_tabel
GROUP BY
	platform
	
-- частота обновления в разрезе мобильных ОС
WITH users_stats AS (
	SELECT
		puid,
		usage_platform_ru AS platform,
		IF(length(groupUniqArray(app_version)) - 1 < 0, 0, length(groupUniqArray(app_version)) - 1) AS cnt_updates
	FROM 
		source_db.audition
	WHERE 
		usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
	GROUP BY 
		puid, platform
)
SELECT
	platform,
	ROUND(AVG(cnt_updates), 2) AS update_rate
FROM
	users_stats
GROUP BY
	platform

	
-- кол-во книг с тегом «Магия»
SELECT
	uniqExact(main_content_id) AS cnt_books
FROM 
	source_db.content
WHERE
	has(published_topic_title_list, 'Магия')
	AND length(published_topic_title_list) <= 4
	ANd NOT has(published_topic_title_list, 'Художественная литература')

	
-- все книги со словом «магия» в названии, для которых не проставлен тег «Магия» и «Художественная литература»	
SELECT
	uniqExact(main_content_id) AS cnt_books
FROM 
	source_db.content
WHERE
	NOT has(published_topic_title_list, 'Художественная литература')
	AND NOT has(published_topic_title_list, 'Магия')
	AND  main_content_name ILIKE '%магия%'
	
	
-- Среднее кол-во тегов в зависимости от категории	
WITH pre_table AS (
SELECT
	*,
	IF(has(published_topic_title_list, 'Магия'), 'Магия', 'Все книги') AS segment,
	length(published_topic_title_list) AS cnt_topics
FROM 	
	source_db.content
WHERE
	length(published_topic_title_list) <= 4
--GROUP BY 
--	main_content_id, segment
)
SELECT
	segment,
	ROUND(AVG(cnt_topics), 2)
FROM 
	pre_table
WHERE
	segment = 'Магия'
GROUP BY 
	segment
UNION ALL
SELECT
	segment,
	ROUND(AVG(cnt_topics), 2)
FROM 
	pre_table
WHERE
	segment != 'Магия'
GROUP BY 
	segment
	
	
-- поиск аномалии в длительности сессии
WITH pre_stats AS (
SELECT
	usage_country_name AS country,
	usage_platform_ru AS platform,
	AVG(hours_sessions_long) AS avg_hours,
	stddevSamp(hours_sessions_long) AS stddev_hours
FROM
	source_db.audition
WHERE
	usage_platform_ru IN ('Букмейт iOS', 'Букмейт Android')
	AND hours_sessions_long > 0
	AND hours_sessions_long IS NOT NULL
GROUP BY 
	country, platform
)
SELECT
	country,
	platform,
	ROUND(stddev_hours / avg_hours, 2) AS cv
FROM 
	pre_stats
WHERE 
	avg_hours > 0
ORDER BY 
	cv DESC
LIMIT 1;