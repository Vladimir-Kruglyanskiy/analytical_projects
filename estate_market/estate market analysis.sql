--  #1: Время активности объявлений
WITH
limits AS ( --выводим перцентили 99 и 1, чтобы определить аномальные значения
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) within GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM
	real_estate.flats
),
filtr_id AS (--выводи id без аномалий
SELECT
	id
FROM
	real_estate.flats
WHERE
	total_area < (SELECT total_area_limit FROM limits)
	AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
	AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
), 
stat AS (
SELECT
	CASE -- категория  Питер и ЛенОбл
		WHEN f.city_id = '6X8I'
			THEN 'Санкт-Петербург'
		ELSE 'ЛенОбл'
	END AS region,
	CASE -- категория по длительности
		WHEN a.days_exposition BETWEEN 1 AND 30
			THEN 'до месяца'
		WHEN a.days_exposition BETWEEN 31 AND 90
			THEN 'до квартала'
		WHEN a.days_exposition BETWEEN 91 AND 180
			THEN 'до полгода'
		WHEN a.days_exposition IS NULL
			THEN 'Другое'
		ELSE 'более полугода'
	END AS PERIOD,
	a.last_price / f.total_area AS price_1m, --цена 1м. кв.
	f.total_area, -- общ площадь
	f.rooms, -- кол-во комнат
	COALESCE(f.balcony, 0) AS balcony, -- кол-во балконов, если значение NULL, то будем считать, что балконов нет, т.е. = 0
	f.floor, -- этаж квартиры
	f.ceiling_height, --высота потолков
	f.ponds_around3000, --кол-во водоемов
	f.parks_around3000, -- кол-во паковок
	f.airports_nearest, -- расстояние до аэропорта
	f.is_apartment, --признак аппартамента
	f.open_plan -- признак открытой планировки
FROM
	real_estate.flats AS f
JOIN
	real_estate.advertisement AS a USING(id)
WHERE
	f.type_id = 'F8EM' -- отбираем тип населенного пункта "город"
	AND f.id IN (SELECT * FROM filtr_id) --отбираем Id без аномалий
	AND DATE_TRUNC('year', a.first_day_exposition) BETWEEN '2015-01-01' AND '2018-01-01'
ORDER BY
	region DESC
)
SELECT --основной запрос
	region,
	PERIOD,
	COUNT(*) AS count_advertisement, -- кол-во объявлений
	ROUND(COUNT(*)::numeric / SUM(COUNT(*)) OVER (PARTITION BY region), 2) AS share_advertisement, -- доля от объявлений в разрезе региона
	ROUND(AVG(price_1m)::numeric) AS avg_price_1m, -- сред. цена за 1 кв.м.
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area, -- ср. площадь
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms, -- медиана кол-во комнат
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony, -- медиана по балконам
	ROUND(AVG(ceiling_height)::NUMERIC, 2) AS avg_ceiling_height, -- ср. высота потолка
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS mediana_floor,  -- медиана по этажу квартиры
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS mediana_ponds, --медиана по водоемам
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS mediana_parks, --медиана по паркам
	ROUND(AVG(airports_nearest)::NUMERIC / 1000) AS avg_airports_nearest_km, -- сред. расстояние до аэропорта в км
	ROUND(SUM(is_apartment) / COUNT(*)::NUMERIC*100, 2) AS percent_apartment, -- процент аппартаментов
	ROUND(SUM(open_plan) / COUNT(*)::NUMERIC * 100, 2) AS percent_open_plan, --процент с открытой планировкой
	ROUND(COUNT(rooms) FILTER(WHERE rooms = 0) / COUNT(*)::NUMERIC * 100, 2) AS percent_studio -- процент студий
FROM
	stat
GROUP BY
	region,
	PERIOD
ORDER BY
	region
;


--#2: Сезонность объявлений

WITH
limits AS ( --выводим перцентили 99 и 1, чтобы определить аномальные значения
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) within GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM
	real_estate.flats
),
filtr_id AS (--выводи id без аномалий
SELECT
	id
FROM
	real_estate.flats
WHERE
	total_area < (SELECT total_area_limit FROM limits)
	AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
	AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
per_stat AS (--подготавливаем данные
SELECT
	a.first_day_exposition,
	a.first_day_exposition + (a.days_exposition || 'days')::INTERVAL AS day_of_sale, --находим дату продажи
	a.last_price,
	f.total_area
FROM
	real_estate.advertisement AS a
JOIN
	real_estate.flats AS f USING(id)
WHERE
	a.id IN (SELECT * FROM filtr_id)
	AND f.type_id = 'F8EM' -- отбираем тип населенного пункта "город"
	AND DATE_TRUNC('year', a.first_day_exposition) BETWEEN '2015-01-01' AND '2018-01-01'
),
stat_public AS ( -- считаем активность публикаций объявлений
SELECT
	EXTRACT(MONTH FROM first_day_exposition::timestamp) AS month_publication, -- месяц публикации объявлений
	COUNT(EXTRACT(MONTH FROM first_day_exposition::timestamp)) AS  count_publication, --кол-во публикаций
	COUNT(EXTRACT(MONTH FROM first_day_exposition::timestamp)) / SUM(COUNT(EXTRACT(MONTH FROM first_day_exposition::timestamp))) OVER() AS share_public,
	ROUND(AVG(last_price /total_area )::NUMERIC, 2) AS avg_price_publ, -- сред. цена за кв.м.
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_publ, --сред. площадь
	DENSE_RANK() OVER (ORDER BY COUNT(EXTRACT(MONTH FROM first_day_exposition::timestamp)) DESC) AS rank_public --ранг по кол-во публикаций
FROM 
	per_stat
GROUP BY
	month_publication
ORDER BY 	
	month_publication  
),
stat_sale AS ( --считаем данные по продажам
SELECT
	EXTRACT(MONTH FROM day_of_sale::timestamp) AS month_sale, --месяц продажи
	COUNT(EXTRACT(MONTH FROM day_of_sale::timestamp)) AS count_sale, --кол-во продаж
	COUNT(EXTRACT(MONTH FROM day_of_sale::timestamp)) / SUM(COUNT(EXTRACT(MONTH FROM day_of_sale::timestamp))) OVER() AS share_sale,
	ROUND(AVG(last_price / total_area)::NUMERIC, 2) AS avg_price_sale, -- сред. цена за кв.м.
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area_sale, -- средю площадь
	DENSE_RANK() OVER (ORDER BY COUNT(EXTRACT(MONTH FROM day_of_sale::timestamp)) DESC) AS rank_sale -- ранг по продажам
FROM 	
	per_stat
WHERE
	EXTRACT(MONTH FROM day_of_sale::timestamp) IS NOT NULL
GROUP BY
	month_sale
ORDER BY
	month_sale
)
SELECT --собираем итоговуб таблицу
	CASE p.month_publication
        WHEN 1 THEN 'Январь'
        WHEN 2 THEN 'Февраль'
        WHEN 3 THEN 'Март'
        WHEN 4 THEN 'Апрель'
        WHEN 5 THEN 'Май'
        WHEN 6 THEN 'Июнь'
        WHEN 7 THEN 'Июль'
        WHEN 8 THEN 'Август'
        WHEN 9 THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS MONTH,
	p.count_publication, -- кол-во публикаций
	ROUND(p.share_public, 2) AS share_public, 
	s.count_sale, -- кол-во продаж
	ROUND(s.share_sale, 2) AS share_sale, 
	p.avg_price_publ, --ср. цена за 1 кв.м., когда объявление публиковалось
	s.avg_price_sale, --ср. цена за 1 кв.м.при продаже
	p.avg_total_area_publ, -- срю площадь (публикация)
	s.avg_total_area_sale, -- ср. площадь (продажа)
	p.rank_public, --ранг публикаций
	s.rank_sale --ранг продаж
FROM
	stat_public AS p 
JOIN
	stat_sale AS s ON p.month_publication = s.month_sale
ORDER BY p.month_publication
;


-- #3: Анализ рынка недвижимости Ленобласти
WITH
limits AS ( --выводим перцентили 99 и 1, чтобы определить аномальные значения
SELECT
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
	PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
	PERCENTILE_DISC(0.01) within GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
FROM
	real_estate.flats
),
filtr_id AS (--выводи id без аномалий
SELECT
	id
FROM
	real_estate.flats
WHERE
	total_area < (SELECT total_area_limit FROM limits)
	AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
	AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
	AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits) AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
stat AS ( --подготавливаем данные для основного запроса
SELECT
	c.city,
	COUNT(*) OVER (PARTITION BY city) AS count_publ, --Кол-во публикаций в разреже населенного пункта
	COUNT(a.days_exposition) OVER (PARTITION BY city) AS count_sale, -- Кол-во продаж в разреже населенного пункта
	f.total_area, -- площадь
	a.last_price / f.total_area AS price_1m, -- цена 1 кв.м.
	f.floor, -- этаж кв
	f.rooms, -- кол-во комнат
	f.ceiling_height, --высота потолков
	COALESCE(f.balcony, 0) AS balcony, -- кол-во балконов. если значене NULL, то считаем, что балкона нет
	a.days_exposition --активность объявления (в днях)
FROM 	
	real_estate.flats AS f
JOIN
	real_estate.advertisement AS a USING(id)
LEFT JOIN 
	real_estate.city AS c USING(city_id)
WHERE
	city NOT ILIKE 'Санкт%'
	AND f.id IN (SELECT * FROM filtr_id)
)
SELECT
	city,
	COUNT(*) AS count_public, -- кол-во публикаций
	ROUND(AVG(count_sale / count_publ::numeric), 2) AS share_sale, -- доля продаж
	ROUND(AVG(total_area)::NUMERIC, 2) AS avg_total_area, --ср. пложадь
	ROUND(AVG(price_1m)::NUMERIC, 2) AS avg_price_1m, -- сред. уена за 1 кв.м.
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS mediana_floor, -- медина по этажу кв
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS mediana_rooms, -- медиана по кол-во комнат
	ROUND(AVG(ceiling_height)::NUMERIC, 2) AS avg_ceiling_height, -- сред. вымота потолков
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS mediana_balcony, -- медиана по балконам
	ROUND(AVG(days_exposition)::NUMERIC, 2) AS avg_days_exposition, -- сред. активность объясвления 
	NTILE(4) OVER(ORDER BY AVG(days_exposition)) AS rank_sale
FROM
	stat
GROUP BY
	city
ORDER BY
	count_public DESC
LIMIT
	15
;

