/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Мулашкина Татьяна Игоревна
 * Дата: 28.01.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT(id) AS count_users,
	   SUM(payer) AS count_payer_users, 
	   ROUND(AVG(payer), 3) AS rate_payer_users
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race, 
	   SUM(payer) AS count_payer_users_per_race, 
	   COUNT(id) AS count_users_per_race, 
	   ROUND(AVG(payer), 3) AS rate_payer_users_per_race 
FROM fantasy.users 
LEFT JOIN fantasy.race USING(race_id)
GROUP BY race
ORDER BY rate_payer_users_per_race DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS total_events, 
	   SUM(amount) AS total_amount,
	   MIN(amount) AS min_amount,
	   MAX(amount) AS max_amount,
	   AVG(amount) AS avg_amount,
	   PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount,
	   STDDEV(amount) AS stand_dev_amount
FROM fantasy.events
WHERE amount <> 0;

-- 2.2: Аномальные нулевые покупки:
--Подзапрос, в котором стоимость покупок с нулевой стоимостью заменяется на значение NULL
WITH  amount_with_null AS (SELECT CASE 
				 					WHEN amount = 0 THEN NULL
				 					ELSE amount
				 				  END AS amount
	  					   FROM fantasy.events
	  					   ) 
--Вычисление количества нулевых покупок как разницы между всеми покупками и покупками с ненулевой стоимостью
SELECT COUNT(*) - COUNT(amount) AS count_null_amount, 
	   (COUNT(*) - COUNT(amount))/COUNT(*)::real AS rate_count_null_amount
FROM amount_with_null;

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- CTE в котором рассчитывается количество и сумма покупок для каждого пользователя, 
-- В присоединение таблицы evnets используется подзапрос, чтобы исключить покупки с нулевой стоимостью
WITH count_sum_per_users AS (SELECT u.payer, 
       COUNT(e.transaction_id) AS count_transaction, 
	   SUM(e.amount) AS sum_amount
FROM fantasy.users AS u
INNER JOIN (SELECT * 
		   FROM fantasy.events 
		   WHERE amount <> 0) AS e USING(id)
GROUP BY id, u.payer)
--используя данные CTE разбиваем пользователей на группы: 'платящий' и 'не платящий'
--считаем количество пользователец в каждой группе и среднее количество покупок и суммарной стоимости
SELECT CASE 
			WHEN payer = 0 THEN 'не платящий'
			WHEN payer = 1 THEN 'платящий'
	   END AS payer,
	   COUNT(*) AS count_users,
	   ROUND(AVG(count_transaction)) AS avg_count_transaction,
	   ROUND(AVG(sum_amount)) AS avg_sum_amount
FROM count_sum_per_users
GROUP BY payer;
-- 2.4: Популярные эпические предметы:
-- расчет абсолютного и относительного количества покупок, с учетом только ненулевых стоимостей покупок
-- расчет доли пользователей купивших эпический предмет
-- вывод с условием, что количество покупок предмета больше и равна одной
SELECT game_items, 
	   COUNT(transaction_id) AS count_buy_items,
	   COUNT(transaction_id) :: numeric / (SELECT COUNT(transaction_id) 
	   									   FROM fantasy.events 
	   									   WHERE amount <> 0) AS relative_count_buy_items,
	   COUNT(DISTINCT id) :: numeric / (SELECT COUNT(DISTINCT id)
	   									FROM fantasy.events 
	   									WHERE amount <> 0) AS relative_count_user_per_items
FROM fantasy.items 
LEFT JOIN fantasy.events USING(item_code)
WHERE amount <> 0
GROUP BY game_items
HAVING  COUNT(transaction_id) >= 1
ORDER BY relative_count_user_per_items DESC;


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- для каждой расы количество игроков
WITH CTE1 AS (SELECT r.race, COUNT(id) AS count_users
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u USING(race_id)
GROUP BY r.race),
-- для каждой расы количество игроков, которые совершили покупку, и доля платящих игроков среди них
CTE2 AS (SELECT r.race, COUNT(DISTINCT id) AS count_buying_users,
	   COUNT(DISTINCT id) FILTER(WHERE payer = 1) AS payer_users
FROM fantasy.race AS r
LEFT JOIN fantasy.users AS u USING(race_id)
INNER JOIN (SELECT * 
		   FROM fantasy.events 
		   WHERE amount <> 0) AS e USING(id)
GROUP BY r.race),
-- количество покупок, средняя стоимость и суммарная стоимость для каждого игрока
CTE3 AS (SELECT race, COUNT(e.transaction_id) AS count_transaction_per_user, 
	  SUM(amount) AS sum_amount_per_user
	  FROM fantasy.race AS r
	  LEFT JOIN fantasy.users AS u USING(race_id)
	  INNER JOIN (SELECT * FROM fantasy.events WHERE amount <> 0) AS e USING(id)
	  GROUP BY race, id),
-- среднее количество покупок, средняя стоимость и средняя суммарная стоимость для каждой расы	  
CTE4 AS (SELECT race, ROUND(AVG(count_transaction_per_user)) AS avg_count_tr_per_user, 
	    ROUND(AVG(sum_amount_per_user)) AS avg_sum_amount_per_user
FROM CTE3
GROUP BY race)
--вывод нужных показателей и расчет доли покупающих игроков
SELECT CTE1.race, count_users, count_buying_users, 
	   ROUND(count_buying_users/count_users::numeric, 3) AS rate_buying_users, 
       ROUND(payer_users/count_buying_users::NUMERIC, 3) AS rate_payer_user, avg_count_tr_per_user,  ROUND(avg_sum_amount_per_user/avg_count_tr_per_user) AS avg_amount_per_user, avg_sum_amount_per_user
FROM CTE1
LEFT JOIN CTE2 USING(race)	  
LEFT JOIN CTE4 USING(race);

-- Задача 2: Частота покупок
-- кол-во дней между двумя покупками пользователя, учтены только покупки с ненулевой стоимостью
WITH interval_between_transaction AS (SELECT *,
	   (date::date - LAG(date::date) OVER(PARTITION BY id ORDER BY date)) AS intervals_per_user
FROM fantasy.events
WHERE amount <> 0),
--кол-во покупок и среднее кол-во дней между покупками для каждого игрока
count_transaction_days AS (SELECT id, COUNT(transaction_id) AS count_transaction,
ROUND(AVG(intervals_per_user), 2) AS avg_interval_between_transaction
FROM interval_between_transaction
GROUP BY id),
--ранжирование (на 3 группы) по среднему кол-ву дней между покупками
--учитываем пользователей только с количеством покупок не менее 25
rank_user AS (SELECT NTILE(3) OVER(ORDER BY avg_interval_between_transaction DESC) AS rank_user, *
FROM count_transaction_days
WHERE count_transaction >= 25)
--для каждой категории пользователей (по частоте покупок) рассчитываем:
--кол-во игроков, кол-во платящих игроков, долю платящих от всех, среднее кол-во покупок, среднее кол-во дней между покупками
SELECT CASE 
			WHEN rank_user = 1 THEN 'низкая частота'
			WHEN rank_user = 2 THEN 'умеренная частота'
			WHEN rank_user = 3 THEN 'высокая частота'		
	   END AS category_user,
	   COUNT(id) AS count_users,
	   SUM(payer) AS count_payer,
	   ROUND(AVG(payer),3) AS rate_payer,
	   ROUND(AVG(count_transaction)) AS avg_count_transaction,
	   ROUND(AVG(avg_interval_between_transaction), 2) AS avg_days_between_transaction
FROM rank_user
LEFT JOIN fantasy.users AS u USING(id)
GROUP BY rank_user;
