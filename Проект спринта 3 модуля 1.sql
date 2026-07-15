/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Асначёв Даниил Дмитриевич
 * Дата: 12.05.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

WITH
    count_users AS (
               SELECT
                     '1' AS count_id,
                     COUNT(id) AS count_users
               FROM fantasy.users),
               
    count_users_payer AS (
               SELECT 
                     '1' AS count_id,
                     COUNT(id) AS count_users_payer
               FROM fantasy.users
               WHERE payer = 1)

SELECT
      cu.count_users,
      cup.count_users_payer,
      cup.count_users_payer :: NUMERIC / cu.count_users AS part_payer_user
FROM count_users AS cu
INNER JOIN count_users_payer AS cup ON cu.count_id = cup.count_id;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

WITH
    count_users AS (
               SELECT
                     r.race,
                     COUNT(u.id) AS count_users
               FROM fantasy.race AS r
               INNER JOIN fantasy.users AS u ON r.race_id = u.race_id
               GROUP BY r.race),
               
    count_users_payer AS (
               SELECT 
                     r.race,
                     COUNT(u.id) AS count_users_payer
               FROM fantasy.race AS r
               INNER JOIN fantasy.users AS u ON r.race_id = u.race_id
               WHERE payer = 1
               GROUP BY r.race)

SELECT
      cu.race,
      cup.count_users_payer,
      cu.count_users,
      cup.count_users_payer :: NUMERIC / cu.count_users AS part_payer_user
FROM count_users AS cu
INNER JOIN count_users_payer AS cup ON cu.race = cup.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

SELECT
      COUNT(amount) AS count_transaction,
      SUM(amount) AS sum_amount,
      MIN(amount) AS min_amount,
      MAX(amount) AS max_amount,
      AVG(amount) AS avg_amount,
      PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS mediana_amount,
      STDDEV(amount) AS stand_dev_amount
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

WITH
    count_transaction AS (
               SELECT
                     '1' AS count_id,
                     COUNT(amount) AS count_transaction
               FROM fantasy.events),
               
    count_transaction_null AS (
               SELECT 
                     '1' AS count_id,
                     COUNT(amount) AS count_transaction_null
               FROM fantasy.events
               WHERE amount = 0)

SELECT
      ct.count_transaction,
      ctn.count_transaction_null,
      ctn.count_transaction_null :: NUMERIC / ct.count_transaction AS part_amount_null
FROM count_transaction AS ct
INNER JOIN count_transaction_null AS ctn ON ct.count_id = ctn.count_id;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь

WITH
    items_count_transaction AS (
               SELECT 
                     i.item_code,
                     i.game_items,
                     COUNT(e.amount) AS amount_game_items,
                     COUNT(e.amount)::NUMERIC / (SELECT COUNT(amount) AS count_transaction_not_null FROM fantasy.events WHERE amount > 0) AS part_transaction
               FROM fantasy.items AS i 
               INNER JOIN fantasy.events AS e ON i.item_code = e.item_code 
               WHERE amount > 0
               GROUP BY i.item_code, i.game_items),
    part_users AS (
               SELECT 
                     i.item_code,
                     i.game_items,
                     COUNT(DISTINCT e.id) :: NUMERIC / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0) AS part_users
               FROM fantasy.items AS i 
               INNER JOIN fantasy.events AS e ON i.item_code = e.item_code
               WHERE amount > 0
               GROUP BY i.item_code, i.game_items) 
SELECT 
      ict.game_items,
      ict.amount_game_items,
      ict.part_transaction,
      pu.part_users
FROM items_count_transaction AS ict
INNER JOIN part_users AS pu ON ict.item_code = pu.item_code AND ict.game_items = pu.game_items
ORDER BY ict.amount_game_items DESC, ict.part_transaction, pu.part_users;

-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

WITH
    count_users_race AS (
                    SELECT
                          r.race_id,
                          r.race,
                          COUNT(u.id) AS count_users_race
                    FROM fantasy.race AS r
                    INNER JOIN fantasy.users AS u ON r.race_id = u.race_id
                    GROUP BY r.race_id, r.race),
    count_users_amount_race AS (
                    SELECT
                          DISTINCT u.race_id,
                          COUNT(DISTINCT e.id) AS count_users_amount_race
                    FROM fantasy.users AS u 
                    INNER JOIN fantasy.events AS e ON u.id = e.id 
                    WHERE amount > 0
                    GROUP BY DISTINCT u.race_id),
    count_users_payer_race AS (
                    SELECT
                          DISTINCT u.race_id,
                          COUNT(DISTINCT u.id)  AS count_users_payer_race
                    FROM fantasy.users AS u
                    INNER JOIN fantasy.events AS e ON u.id = e.id 
                    WHERE payer = 1 AND amount > 0 
                    GROUP BY DISTINCT u.race_id),
    avg_user_transaction AS (
                    SELECT 
                          user_tx.race_id,
                          AVG(user_transaction_count) AS avg_user_transaction
                    FROM (
                           SELECT 
                                 u.race_id,
                                 u.id,
                                 COUNT(e.transaction_id) AS user_transaction_count
                           FROM fantasy.users AS u
                           INNER JOIN fantasy.events AS e ON u.id = e.id 
                           WHERE e.amount > 0
                           GROUP BY u.race_id, u.id
                         ) AS user_tx
                    GROUP BY user_tx.race_id),
    avg_user_amount_one_transaction AS (
                    SELECT 
                          DISTINCT u.race_id,
                          AVG(e.amount) AS avg_user_amount_one_transaction
                    FROM fantasy.users AS u
                    INNER JOIN fantasy.events AS e ON u.id = e.id 
                    WHERE amount > 0
                    GROUP BY DISTINCT u.race_id),
    avg_amount_all_transaction_user AS (
                    SELECT
                          user_total.race_id,
                          AVG(user_total.total_amount) AS avg_amount_all_transaction_user
                    FROM (
                           SELECT 
                                 u.race_id,
                                 u.id,
                                 SUM(e.amount) AS total_amount
                           FROM fantasy.users AS u
                           INNER JOIN fantasy.events AS e ON u.id = e.id
                           WHERE e.amount > 0
                           GROUP BY u.race_id, u.id
                         ) AS user_total
                    GROUP BY race_id)
SELECT
      cur.race,
      cur.count_users_race,
      cuar.count_users_amount_race,
      cuar.count_users_amount_race :: NUMERIC / cur.count_users_race AS part_amount_users,
      cupr.count_users_payer_race :: NUMERIC / cuar.count_users_amount_race AS part_amount_payer_users,
      aut.avg_user_transaction,
      auaot.avg_user_amount_one_transaction,
      aaatu.avg_amount_all_transaction_user
FROM count_users_race AS cur
INNER JOIN count_users_amount_race AS cuar ON cur.race_id = cuar.race_id 
INNER JOIN count_users_payer_race AS cupr ON cuar.race_id = cupr.race_id 
INNER JOIN avg_user_transaction AS aut ON cupr.race_id = aut.race_id 
INNER JOIN avg_user_amount_one_transaction AS auaot ON aut.race_id = auaot.race_id 
INNER JOIN avg_amount_all_transaction_user AS aaatu ON auaot.race_id = aaatu.race_id;
