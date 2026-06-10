/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков


-- 1.1. Доля платящих пользователей по всем данным:

SELECT
	COUNT(id) AS total_gamers, -- общее кол-во играков
	SUM(payer) AS total_pay_gamer, -- кол-во играков, которые покупают игровую валюту
	ROUND(SUM(payer) / COUNT(id)::NUMERIC,3) AS share_pay --доля платящих игроков от общего количества пользователей, зарегистрированных в игре.
FROM
	fantasy.users 
;
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:

SELECT
	r.race,
	SUM(payer) AS total_pay_gamer, --кол-во платящих пользователей в разрезе расы персонажа
	COUNT(id) AS total_gamers, -- общее кол-во пользователей в разрезе расы персонажа
	ROUND(AVG(payer),3) AS share_pay_race --доля платящих игроков от общего количества пользователей в разрезе  расы персонажа
FROM 
	fantasy.users AS u 
LEFT JOIN
	fantasy.race AS r USING(race_id)
GROUP BY 	
	r.race
ORDER BY 
	share_pay_race DESC
;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:

SELECT
	COUNT(transaction_id) AS total_transaction, -- всего операций 
	SUM(amount) AS sum_amount, --общая стоимость всех покупок
	MIN(amount) AS min_amount, --минимальная стоимость транзакции
	MIN(amount) FILTER (WHERE amount > 0) AS min_amount_without_null,--минимальная стоимость транзакции без нулевых значений
	MAX(amount) AS max_amount, -- максимальная стоимость транзакции
	AVG(amount)::NUMERIC(10, 2) AS avg_amount, --средняя стоимость 
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount, --медиана
	STDDEV(amount)::NUMERIC(10, 2) AS stddev_amount --стандартное отклонени
FROM
	fantasy.events
;

-- 2.2: Аномальные нулевые покупки:

SELECT
	COUNT(transaction_id) AS total_amount,
	COUNT(transaction_id) FILTER (WHERE amount = 0) AS count_null_amount,
	COUNT(transaction_id) FILTER (WHERE amount = 0) / COUNT(transaction_id)::real * 100 AS  share_null_amount -- вычисляем долю 0ых транзакций
FROM
	fantasy.events
;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:

WITH
stat AS ( --считаем кол-во покупок и сумму покупок для каждого игрока
SELECT
	e.id,
	u.payer,
	COUNT(e.transaction_id) AS count_tra,
	SUM(amount) AS sum_amo
FROM 
	fantasy.users AS u 
LEFT JOIN 
	fantasy.events AS e USING(id)
WHERE
	e.amount > 0
GROUP BY
	e.id,
	u.payer
)
SELECT
	CASE 
		WHEN payer = 1
			THEN 'платящий'
		ELSE 'неплатящий'
	END AS payer,
	COUNT(id) AS count_gamers,
	ROUND(AVG(count_tra)::numeric, 3) AS avg_count_transaction,
	ROUND(AVG(sum_amo)::numeric, 3) AS avg_amount
FROM 
	stat
GROUP BY
	payer
;
-- доп таблица: активности платящих и неплатящих игроков в разрезе расы
WITH
stat AS (
SELECT
	e.id,
	u.payer,
	r.race,
	COUNT(e.transaction_id) AS count_tra,
	SUM(amount) AS sum_amo
FROM 
	fantasy.users AS u 
LEFT JOIN 
	fantasy.events AS e USING(id)
LEFT JOIN
	fantasy.race AS r USING(race_id)
WHERE
	e.amount > 0
GROUP BY
	e.id,
	u.payer,
	r.race
)
SELECT
	CASE 
		WHEN payer = 1
			THEN 'платящий'
		ELSE 'неплатящий'
	END AS payer,
	race,
	COUNT(id) AS count_gamers,
	ROUND(AVG(count_tra)::numeric, 3) AS avg_count_transaction,
	ROUND(AVG(sum_amo)::numeric, 3) AS avg_amount
FROM 
	stat
GROUP BY
	payer,
	race
ORDER BY 
	race,
	payer 
;

-- 2.4: Популярные эпические предметы:

SELECT
	i.item_code, 
	i.game_items,
	COUNT(e.transaction_id) AS ablosut_count, -- Общ. кол-во транзакций
	COUNT(e.transaction_id) / (SELECT COUNT(*) FILTER (WHERE amount > 0) FROM fantasy.events)::real AS share_transaction, -- доля продаж от общеего кол-ва
	COUNT(DISTINCT e.id)::real / (SELECT COUNT(DISTINCT id) FILTER(WHERE amount > 0) FROM fantasy.events) AS share_gamers -- доля клиентов от общего кол-ва 
FROM 
	fantasy.items  AS i
LEFT JOIN
	fantasy.events AS e USING(item_code)
WHERE
	e.amount > 0
GROUP BY
	i.item_code, 
	i.game_items
ORDER BY
	ablosut_count DESC
;

--доп таблица: список предметов, которые не купили
SELECT
	i.item_code,
	i.game_items,
	e.transaction_id
FROM
	fantasy.items AS i
LEFT JOIN
	fantasy.events AS e USING(item_code)
WHERE 
	e.transaction_id IS NULL
;

-- 2.5 Зависимость активности игроков от расы персонажа:

WITH 
total_info AS ( --Ищем количество зарегистрированных и платящих игроков в разрезе расы
SELECT 
	DISTINCT r.race_id,
	r.race,
	COUNT(u.id) OVER(PARTITION BY r.race_id) AS count_total_gamers, -- всего игроков в разрезе расы
	SUM(u.payer) OVER(PARTITION BY r.race_id) AS count_payer -- кол-во платящих игроков в разрезе расы
FROM
	fantasy.users AS u 
LEFT JOIN 
	fantasy.race AS r USING(race_id) 
),
info_pay_gamer AS ( -- Ищем игроков, которые совершали покупку в разрезе расы
SELECT
	r.race_id,
	r.race,
	COUNT(DISTINCT e.id) AS count_pay_gamer, --Кол-во игроков, которые совершают покупки
	COUNT(DISTINCT e.id) FILTER (WHERE u.payer = 1) AS c_pay_buy_gamer --кол-во игроков, которые покупают игровую валюту и совершают покупки
FROM
	fantasy.events AS e
LEFT JOIN
	fantasy.users AS u USING(id)
LEFT JOIN 
	fantasy.race AS r USING(race_id)
WHERE 
	e.amount <> 0
GROUP BY
	r.race_id,
	r.race
),
share_pay AS ( -- Ищем долю игроков: 1) платящих игроков от количества игроков, которые совершили покупки. 2) доля игроков, которые совершают внутриигровые покупки, от общего кол-ва.
SELECT
	*,
	pg.c_pay_buy_gamer / pg.count_pay_gamer::REAL AS share_of_payer, --Доля платящих игроков от количества игроков, которые совершили покупки 
	pg.count_pay_gamer / ti.count_total_gamers::REAL AS share_pay_gamer --Доля игроков, которые совершают внутриигровые покупки, от общего кол-ва
FROM
	total_info AS ti 
LEFT JOIN
	info_pay_gamer AS pg USING(race_id, race)
),
stat_race AS ( -- считаем инфу по кол-ву заказов и суммам в разрезе расы
SELECT
	 DISTINCT r.race_id,
	r.race,
	COUNT(e.transaction_id) OVER(PARTITION BY r.race_id) AS count_transaction, --кол-во покупок в разрезе расы
	AVG(e.amount) OVER(PARTITION BY r.race_id) AS avg_amount, --средняя стоимость в разрезе расы
	SUM(e.amount) OVER(PARTITION BY r.race_id) AS sum_amount -- сумма заказов в разрезе расы
FROM
	fantasy.events AS e
LEFT JOIN
	fantasy.users AS u USING(id)
LEFT JOIN 
	fantasy.race AS r USING(race_id)
WHERE 
	e.amount <> 0
)
SELECT
	p.race_id, -- айди расы
	p.race, -- название расы
	p.count_total_gamers, -- общее кол-во игроков в разрезе расы
	p.count_pay_gamer, -- аблосютное кол-во игроков, которые совершают покупки
	ROUND(p.share_pay_gamer::numeric, 3) AS share_pay_gamer, -- доля игроков, которые совершают покупки от общего кол-ва игроков
	ROUND(p.share_of_payer::numeric, 3) AS share_of_payer, --Доля платящих игроков от количества игроков, которые совершили покупки  
	ROUND(sr.count_transaction / p.count_pay_gamer::NUMERIC, 3) AS count_transaction_per_gamer, -- среднее количество покупок на одного игрока 
	ROUND(sr.sum_amount::numeric /  (sr.count_transaction::NUMERIC), 3) AS avg_amount_per_gamer, --средняя стоимость одной покупки на одного игрока
	ROUND(sr.sum_amount::numeric / (p.count_pay_gamer::NUMERIC), 3) AS sum_amount_per_gamer --средняя суммарная стоимость всех покупок на одного игрока
FROM 	
	share_pay AS p
LEFT JOIN 
	stat_race AS sr USING(race_id, race)
ORDER BY
	sum_amount_per_gamer DESC
;


