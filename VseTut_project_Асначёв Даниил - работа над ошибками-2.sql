/* Проект «Разработка витрины и решение ad-hoc задач»
 * Цель проекта: подготовка витрины данных маркетплейса «ВсёТут»
 * и решение четырех ad hoc задач на её основе
 * 
 * Автор: Асначёв Даниил Дмитриевич
 * Дата: 02.06.2026
*/



/* Часть 1. Разработка витрины данных
 * Напишите ниже запрос для создания витрины данных
*/

/*
 Не очень понятно, что считать датой и временем первого и последнего заказа. Какое время брать за время заказа?
 По идее за дату и время заказа нужно брать order_purchase_ts - время покупки. 
 Но у 67961 закакзов order_approved_at — время подтверждения заказа меньше order_purchase_ts — времени покупки.
 Казалось бы такого не должно быть, так как сначала пользователь должен купить товар, а потом магазин это подтвердить.
 Поэтому я решил, что order_approved_at — время подтверждения заказа и есть время заказа, но
 в 31319 всё наоборот. Поэтому я решил, что за время заказа всё-таки буду считать время покупки.
 */


/*СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО*/
WITH all_table AS (
WITH top_region_product_results AS (
    SELECT 
          u.region,
          COUNT(o.order_id) AS count_order_id
/*          Я исправил на order_id, но число order_id = числу buyer_id
            SELECT COUNT(order_id), COUNT(buyer_id)
            FROM ds_ecom.orders;
 */
    FROM ds_ecom.users AS u
    INNER JOIN ds_ecom.orders AS o ON u.buyer_id = o.buyer_id
    GROUP BY u.region
    ORDER BY count_order_id DESC
    LIMIT 3
    ),  

    top_region AS (
    SELECT 
          u.buyer_id,
          u.user_id,
          trpr.region 
    FROM ds_ecom.users AS u
    INNER JOIN top_region_product_results AS trpr ON u.region = trpr.region
    ),
    two_order_status AS (
    SELECT 
          order_id,
          buyer_id,
          order_status
    FROM ds_ecom.orders
    WHERE order_status = 'Доставлено' OR order_status = 'Отменено'),
    lifetime AS (
    SELECT 
          tr.user_id,
          tr.region,
          MIN(o.order_purchase_ts) AS first_order_ts,
          MAX(o.order_purchase_ts) AS last_order_ts,
          DATE_TRUNC('second', MAX(o.order_purchase_ts) - MIN(o.order_purchase_ts)) AS lifetime
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    GROUP BY tr.user_id, tr.region
    ),
    total_orders AS (
    SELECT
          tr.user_id,
          tr.region,
          COUNT(o.order_id) AS total_orders
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    GROUP BY tr.user_id, tr.region
    ),
    avg_order_rating_product_results AS (
    SELECT
          tr.user_id,
          tr.region,
          o.order_id,
          CASE 
          	WHEN ore.review_score < 51 AND ore.review_score > 9
          	  THEN ore.review_score / 10
          	ELSE ore.review_score
          END
          
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    INNER JOIN ds_ecom.order_reviews AS ore ON o.order_id = ore.order_id
    ),
    avg_order_rating AS (
    SELECT
          user_id,
          region,
          ROUND(AVG(review_score), 2) AS avg_order_rating
    FROM avg_order_rating_product_results
    GROUP BY user_id, region
    ),
    num_orders_with_rating_not_zero AS (
    SELECT
          user_id,
          region,
          CASE
          	WHEN review_score IS NOT NULL
          	  THEN order_id
          	ELSE NULL
          END AS order_id
    FROM avg_order_rating_product_results
    ),
    num_orders_with_rating AS (
    SELECT
          user_id,
          region,
          COUNT(order_id) AS num_orders_with_rating
    FROM num_orders_with_rating_not_zero
    GROUP BY user_id, region
    ),
    num_canceled_orders_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          CASE
          	WHEN tos.order_status = 'Отменено'
          	   THEN o.order_id
          	ELSE NULL
          END AS order_id,
          tos.order_status
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    ),
    num_canceled_orders AS (
    SELECT 
          user_id,
          region,
          COUNT(order_id) AS num_canceled_orders
    FROM num_canceled_orders_product_results
    GROUP BY user_id, region
    ), 
    canceled_orders_ratio AS (
    SELECT 
          tor.user_id,
          tor.region,
          nco.num_canceled_orders,
          tor.total_orders,
          ROUND(nco.num_canceled_orders :: NUMERIC / tor.total_orders, 4) AS canceled_orders_ratio
    FROM total_orders AS tor
    INNER JOIN num_canceled_orders AS nco ON tor.user_id = nco.user_id
    ),
    total_order_costs_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          CASE
          	WHEN o.order_status = 'Доставлено' 
          	  THEN COALESCE(price, 0) + COALESCE(delivery_cost, 0)
          	ELSE NULL
          END AS price_delivery_cost
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    INNER JOIN ds_ecom.order_items AS oi ON o.order_id = oi.order_id
    ),
    total_order_costs AS (
    SELECT 
          user_id,
          region,
          ROUND(SUM(price_delivery_cost), 2) AS total_order_costs
    FROM total_order_costs_product_results
    GROUP BY user_id, region
    ),
    total_orders_for_avg_order_cost AS (
    SELECT
          tr.user_id,
          tr.region,
          CASE
          	WHEN o.order_status = 'Доставлено' 
          	  THEN o.order_id
          	ELSE NULL
          END AS avg_order_cost_order_id
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    ),
    count_orders_for_avg_order_cost AS (
    SELECT
          user_id,
          region,
          COUNT(avg_order_cost_order_id) AS total_orders_for_avg_order_cost
    FROM total_orders_for_avg_order_cost
    GROUP BY user_id, region
    ),
    avg_order_cost AS (
    SELECT 
          cofaoc.user_id,
          cofaoc.region,
          cofaoc.total_orders_for_avg_order_cost,
          ROUND(toc.total_order_costs :: NUMERIC / cofaoc.total_orders_for_avg_order_cost, 2) AS avg_order_cost
    FROM count_orders_for_avg_order_cost AS cofaoc
    INNER JOIN total_order_costs AS toc ON cofaoc.user_id = toc.user_id AND cofaoc.region = toc.region
    ),
    num_installment_orders_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          CASE
          	WHEN payment_installments > 1
          	  THEN o.order_id 
          	ELSE NULL
          END AS order_id
          
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    INNER JOIN ds_ecom.order_payments AS op ON o.order_id = op.order_id
    ),
    num_installment_orders AS (
    SELECT 
          user_id,
          region,
          COALESCE(COUNT(order_id), 0) AS num_installment_orders
    FROM num_installment_orders_product_results
    GROUP BY user_id, region
    ),
    num_orders_with_promo_product_results AS (
    SELECT
          tr.user_id,
          tr.region,
          CASE
          	WHEN op.payment_type = 'промокод'
          	  THEN o.order_id 
          	ELSE NULL
          END AS order_id
          
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    INNER JOIN ds_ecom.order_payments AS op ON o.order_id = op.order_id
    ),
    num_orders_with_promo_group_payment_type AS (
    SELECT 
          user_id,
          region,
          order_id
    FROM num_orders_with_promo_product_results
    GROUP BY user_id, region, order_id
    ),
    num_orders_with_promo AS (
    SELECT 
          user_id,
          region,
          COALESCE(COUNT(order_id), 0) AS num_orders_with_promo
    FROM num_orders_with_promo_group_payment_type
    GROUP BY user_id, region
    ),
    used_money_transfer_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          o.order_id,
          MIN(o.order_purchase_ts) AS min_pay_with_transfer
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    GROUP BY  tr.user_id, tr.region, o.order_id
    ),
    used_money_transfer_with_min AS (
    SELECT 
          umtpr.user_id,
          umtpr.region,
          CASE
          	WHEN op.payment_type = 'денежный перевод' AND o.order_purchase_ts = min_pay_with_transfer
          	  THEN 1
          	ELSE 0
          END AS used_money_transfer_with_min
    FROM used_money_transfer_product_results AS umtpr
    INNER JOIN ds_ecom.order_payments AS op ON umtpr.order_id = op.order_id
    INNER JOIN ds_ecom.orders AS o ON op.order_id = o.order_id
    ),
    used_money_transfer AS (
    SELECT 
          user_id,
          region,
          CASE
          	WHEN SUM(used_money_transfer_with_min) > 0 
          	  THEN 1
          	ELSE 0
          END AS used_money_transfer
    FROM used_money_transfer_with_min
    GROUP BY user_id, region
    ),
    used_installments_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          CASE
          	WHEN op.payment_installments > 1 
          	  THEN 1
          	ELSE 0
          END AS used_installments_product_results
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    INNER JOIN ds_ecom.order_payments AS op ON o.order_id = op.order_id
    ),
    used_installments AS (
    SELECT 
          user_id,
          region,
          CASE
          	WHEN SUM(used_installments_product_results) > 0 
          	  THEN 1
          	ELSE 0
          END AS used_installments
    FROM used_installments_product_results
    GROUP BY user_id, region
    ),
    used_cancel_product_results AS (
    SELECT 
          tr.user_id,
          tr.region,
          CASE
          	WHEN tos.order_status = 'Отменено'
          	  THEN 1
          	ELSE 0
          END AS used_cancel_product_results
    FROM ds_ecom.orders AS o
    INNER JOIN top_region AS tr ON o.buyer_id = tr.buyer_id 
    INNER JOIN two_order_status AS tos ON tr.buyer_id = tos.buyer_id
    ),
    used_cancel AS (
    SELECT 
          user_id,
          region,
          CASE
          	WHEN SUM(used_cancel_product_results) > 0
          	  THEN 1
          	ELSE 0
          END AS used_cancel
    FROM used_cancel_product_results
    GROUP BY user_id, region
    )

SELECT 
      lifetime.user_id,
      lifetime.region,
      lifetime.first_order_ts,
      lifetime.last_order_ts,
      lifetime.lifetime,
      total_orders.total_orders,
      avg_order_rating.avg_order_rating,
      num_orders_with_rating.num_orders_with_rating,
      num_canceled_orders.num_canceled_orders,
      canceled_orders_ratio.canceled_orders_ratio,
      total_order_costs.total_order_costs,
      avg_order_cost.avg_order_cost,
      num_installment_orders.num_installment_orders,
      num_orders_with_promo.num_orders_with_promo,
      COALESCE(used_money_transfer.used_money_transfer, 0) AS used_money_transfer,
      COALESCE(used_installments.used_installments, 0) AS used_installments,
      COALESCE(used_cancel.used_cancel, 0) AS  used_cancel
FROM lifetime 
LEFT JOIN total_orders ON lifetime.user_id = total_orders.user_id AND lifetime.region = total_orders.region
LEFT JOIN avg_order_rating ON lifetime.user_id = avg_order_rating.user_id AND lifetime.region = avg_order_rating.region
LEFT JOIN num_orders_with_rating ON lifetime.user_id = num_orders_with_rating.user_id AND lifetime.region = num_orders_with_rating.region
LEFT JOIN num_canceled_orders ON lifetime.user_id = num_canceled_orders.user_id AND lifetime.region = num_canceled_orders.region
LEFT JOIN canceled_orders_ratio ON lifetime.user_id = canceled_orders_ratio.user_id AND lifetime.region = canceled_orders_ratio.region
LEFT JOIN total_order_costs ON lifetime.user_id = total_order_costs.user_id AND lifetime.region = total_order_costs.region
LEFT JOIN avg_order_cost ON lifetime.user_id = avg_order_cost.user_id AND lifetime.region = avg_order_cost.region
LEFT JOIN num_installment_orders ON lifetime.user_id = num_installment_orders.user_id AND lifetime.region = num_installment_orders.region
LEFT JOIN num_orders_with_promo ON lifetime.user_id = num_orders_with_promo.user_id AND lifetime.region = num_orders_with_promo.region
LEFT JOIN used_money_transfer ON lifetime.user_id = used_money_transfer.user_id AND lifetime.region = used_money_transfer.region
LEFT JOIN used_installments ON lifetime.user_id = used_installments.user_id AND lifetime.region = used_installments.region
LEFT JOIN used_cancel ON lifetime.user_id = used_cancel.user_id AND lifetime.region = used_cancel.region
GROUP BY lifetime.user_id,
      lifetime.region,
      lifetime.first_order_ts,
      lifetime.last_order_ts,
      lifetime.lifetime,
      total_orders.total_orders,
      avg_order_rating.avg_order_rating,
      num_orders_with_rating.num_orders_with_rating,
      num_canceled_orders.num_canceled_orders,
      canceled_orders_ratio.canceled_orders_ratio,
      total_order_costs.total_order_costs,
      avg_order_cost.avg_order_cost,
      num_installment_orders.num_installment_orders,
      num_orders_with_promo.num_orders_with_promo,
      used_money_transfer.used_money_transfer,
      used_installments.used_installments,
      used_cancel.used_cancel
ORDER BY total_orders.total_orders DESC

)

SELECT *
FROM all_table;

/*Вроде я всё исправил, но в моей таблице 62479 пользователей, в ds_ecom.product_user_features - 62400. Я посмотрел всех этих 79 пользователей и я не понимаю, почему они не подходят.*/


SELECT COUNT(DISTINCT user_id)
FROM all_table;



-- Показать отсутствующих пользователей с их регионами
SELECT DISTINCT 
    at.user_id, 
    at.region,
    at.first_order_ts,
    at.last_order_ts,
    at.lifetime,
    at.total_orders,
    at.avg_order_rating,
    at.num_orders_with_rating,
    at.num_canceled_orders,
    at.canceled_orders_ratio,
    at.total_order_costs,
    at.avg_order_cost,
    at.num_installment_orders,
    at.num_orders_with_promo,
    at.used_money_transfer,
    at.used_installments,
    at.used_cancel
FROM all_table at
LEFT JOIN ds_ecom.product_user_features puf ON at.user_id = puf.user_id
WHERE puf.user_id IS NULL;


SELECT COUNT(DISTINCT user_id)
FROM ds_ecom.product_user_features;





/* Часть 2. Решение ad hoc задач
 * Для каждой задачи напишите отдельный запрос.
 * После каждой задачи оставьте краткий комментарий с выводами по полученным результатам.
*/

/* Задача 1. Сегментация пользователей 
 * Разделите пользователей на группы по количеству совершённых ими заказов.
 * Подсчитайте для каждой группы общее количество пользователей,
 * среднее количество заказов, среднюю стоимость заказа.
 * 
 * Выделите такие сегменты:
 * - 1 заказ — сегмент 1 заказ
 * - от 2 до 5 заказов — сегмент 2-5 заказов
 * - от 6 до 10 заказов — сегмент 6-10 заказов
 * - 11 и более заказов — сегмент 11 и более заказов
*/

-- Напишите ваш запрос тут



/*СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО*/

WITH 
    user_segmentation AS (
    SELECT
          user_id,
          total_orders,
          total_order_costs,
          CASE
    	      WHEN total_orders = 1
    	        THEN '1 заказ'
    	      WHEN total_orders > 1 AND total_orders < 6
    	        THEN 'от 2 до 5 заказов'
    	      WHEN total_orders > 5 AND total_orders < 11
    	        THEN 'от 6 до 10 заказов'
    	      WHEN total_orders > 10
    	        THEN '11 и более заказов'
          END AS user_segmentation
    FROM ds_ecom.product_user_features 
    )
SELECT
      user_segmentation,
      COUNT(user_id) AS total_users,
      ROUND(SUM(total_orders)/COUNT(user_id), 2) AS avg_count_order,
      ROUND(SUM(total_order_costs) :: NUMERIC /SUM(total_orders), 2) AS avg_count_cost
FROM user_segmentation
GROUP BY user_segmentation;


/* Напишите краткий комментарий с выводами по результатам задачи 1.
 *  Из полученных результатов можно сделать несколько выводов. Первое: распределение пользователей по количеству заказов
 * имеет очень резкий спад при переходе из категории с 1 заказом в категорию от 2-х до 5-ти. Пользователей имеющих 1 заказ - 60468, 
 * тогда как пользователей, имеющих от 2х до 5ти заказов,- 1934. Ещё более резкий спад по относительной величине происходит при переходе в категорию
 * от 6-ти до 10ти. Там всего 5 пользователей. Различие между первой категорией и второй: в 30 раз, - а между второй и третьей: в 390 раз. 
 * Поэтому дальше имеет смысл расматривать только первые две категории и изучать данные для них. Если смотреть на среднее количество заказов во второй катеогрии,
 * то оно почти равно 2м. Из этих двух результатов можно сделать вывод, что подавляющее большинство пользователей имеет не более двух заказов за всё время. По средней стоимости заказов
 * между категориями нет особо заметной разницы. Стоит провести дополнительный анализ среднего времени между первым и последним заказом для пользователей, которые имеют от одного до 2х заказов.
 * Изучить какие категории товаров они покупают. Изучить распределение пользователей по категориям товаров. Интересно узнать есть ли связь между количеством заказов на одного пользователя и категорией товара. 
 * Может покупают не товары, которые являются "расходниками", как еда, которую необходимо покупать постоянно, а товары, которые расчитаны на долгий срок: ноутбуки, телефоны и тд.
*/



/* Задача 2. Ранжирование пользователей 
 * Отсортируйте пользователей, сделавших 3 заказа и более, по убыванию среднего чека покупки.  
 * Выведите 15 пользователей с самым большим средним чеком среди указанной группы.
*/

-- Напишите ваш запрос тут

SELECT 
      user_id,
      avg_order_cost,
      total_orders,
      DENSE_RANK() OVER(ORDER BY avg_order_cost DESC)
FROM ds_ecom.product_user_features
WHERE total_orders > 2
LIMIT 15;

/* Напишите краткий комментарий с выводами по результатам задачи 2.
 * Не уверен, что правильно понял условие данной задачи (так как размер запроса сильно меньше, чем предыдущие запросы:)). Если сравнивать 
 * с результатами из предыдущего запроса, то можно заметить увеличение среднего значения стоимости одного заказа у этой выборки из 15-ти
 * человек относительно средних чеков для всех категорий из предыдущего запроса. После предыдущего запроса мы сделали вывод, что подавляющее
 * большинство людей имеют не более двух заказов. Причем средннее значение одного заказа там было не больше 3,5 тысяч. Но в этой выборке самое маленькое значение
 * стоимости заказа 5,5 тысяч, а самое большое - 14,7 тысяч. Возможно есть какая-то связь между количеством заказов и их стоимостью.
 * Возвращаясь к гипотезе о том, что люди покупают не товары-расходники, а товары на долгий срок такие, как ноутбуки, её можно немного изменить. 
 * Если бы люди покупали вещи наподобие ноутбуков, то средний чек был бы сильно больше, чем 3,5 тысячи. И из результатов запроса видно, что наоборот меньшинство делает достаточно дорогие заказы.
 * Значит скорее всего большинство покупает какие-нибудь безделушки. Поэтому ценник не очень большой и, возможно, не очень большое lifetime. Но это необходимо проверить.
*/



/* Задача 3. Статистика по регионам. 
 * Для каждого региона подсчитайте:
 * - общее число клиентов и заказов;
 * - среднюю стоимость одного заказа;
 * - долю заказов, которые были куплены в рассрочку;
 * - долю заказов, которые были куплены с использованием промокодов;
 * - долю пользователей, совершивших отмену заказа хотя бы один раз.
*/

-- Напишите ваш запрос тут
SELECT
      region,
      COUNT(user_id) AS user_count,
      SUM(total_orders) AS sum_orders,
      ROUND(SUM(total_order_costs) :: NUMERIC / SUM(total_orders), 2) AS avg_price_order,
      ROUND(SUM(num_installment_orders) :: NUMERIC / SUM(total_orders), 2) AS share_orders_purchased_using_promo_codes,
      ROUND(SUM(num_orders_with_promo) :: NUMERIC / SUM(total_orders), 4) AS percentage_users_who_made_cancellation
FROM ds_ecom.product_user_features
GROUP BY region
ORDER BY user_count DESC, sum_orders DESC;
/* Напишите краткий комментарий с выводами по результатам задачи 3.
 * Самый явный вывод, который можно сделать на основе результотов запроса: Москва - самый популярный город. В Москве самое большое количество
 * пользователей и заказов (39386) - примерно в 4 раза больше, чем у второго и третьего места - Санкт-Петербурга, Новосибирсокой области. Средние стоимости одного заказа
 * особо не различаются между собой. Хотя средняя стоимость в Москве ниже на 450 рублей, чем в Санкт-Петербурге, когда в Новосибирской области средняя стоимость всего на 100 рублей ниже,
 * чем в Санкт-Петербурге (3600 рублей). Что касается доли заказов, купленных в рассрочку, то Москва как и по предыдущим показателям отличается от Санкт-Петербурга и Новосибирсокй области: 0.48 и 0.54-0.55.
 * Если эти показаетли нужно будет привести к одному значению, то намного проще будет уменьшить показатели в Санкт-Петербурге и Новосибирской области, чем увеличивать этот показатель в Москве. Аналогичный вывод можно сделать и про последний показатель.
 * Так как число людей, которые совершали отмену, в Москве равно 1473, а в Петербурге и Новосибирской области 498 и 406. Интересный факт: население Москвы - 13.3 миллиона, Петербурга - 5.6 миллиона, Новосибирской области - 2.8 миллиона. Если различие в количестве пользователей
 * в Москве и в двух других регионов очевидно в силу гораздо большего населения, то практичсеки не различающиеся количество пользователей и иных показателей в Петербурге и Новосибироской области не очень понятно. Так как население в Петербурге в два раза больше,
 * чем в Новосибирской области. Стоит провести дополнительный анализ типов покупок в двух этих регионах, чтобы понять из-за чего такое различие.
*/



/* Задача 4. Активность пользователей по первому месяцу заказа в 2023 году
 * Разбейте пользователей на группы в зависимости от того, в какой месяц 2023 года они совершили первый заказ.
 * Для каждой группы посчитайте:
 * - общее количество клиентов, число заказов и среднюю стоимость одного заказа;
 * - средний рейтинг заказа;
 * - долю пользователей, использующих денежные переводы при оплате;
 * - среднюю продолжительность активности пользователя.
*/

-- Напишите ваш запрос тут

    
/*СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО-СТАЛО*/   

WITH date_segmentation AS (
    SELECT
        user_id,
        total_orders,
        total_order_costs,
        avg_order_rating,
        used_money_transfer,
        lifetime,
        TO_CHAR(DATE_TRUNC('month', first_order_ts), 'YYYY-MM') AS date_segmentation
    FROM ds_ecom.product_user_features 
    WHERE first_order_ts >= '2023-01-01' 
      AND first_order_ts < '2024-01-01'
)
SELECT 
    date_segmentation,
    COUNT(user_id) AS user_count,
    SUM(total_orders) AS sum_orders,
    ROUND(SUM(total_order_costs)::NUMERIC / SUM(total_orders), 2) AS avg_price_order,
    ROUND(AVG(avg_order_rating), 2) AS avg_rating,
    ROUND(AVG(used_money_transfer), 2) AS part_user_transfer,
    AVG(lifetime) AS avg_lifetime
FROM date_segmentation
WHERE date_segmentation IS NOT NULL
GROUP BY date_segmentation
ORDER BY date_segmentation;

/* Напишите краткий комментарий с выводами по результатам задачи 4.
 * Первое, что хочется отметить, что наблюдается постепенный рост пользователей в течение года. Если сравнивать первые два месяца с последними двумя, то число новых клиентов в месяц выросло в 4 раза. То же самое
касается и числа заказов: наблюдается аналогичный рост с аналогичным результатом. Средняя стоимость заказа не наблюдает постоянного роста в течение года, она колеблется около одного значения (примерно равного 3000).
Аналогично средняя оценка колеблется около одного и того же значения, находящегося в диапазоне от 4.1 до 4.2. Так же доля пользователей, использующих денежные переводы, не увеличилась и не уменьшилась. Но средняя продолжительность активности пользователей
в течение года уменьшается. В начале было 12 дней, в середине года около 6 дней, а к концу - 2 дня. В итоге: по всем показателям, кроме средней активности и средней стоимости заказа, идёт равномерное увеличение числа пользователей. 
А среднее время активности уменьшается. Я думаю, что уменьшение этого показателя можно связать с тем, что первые пользователи маркетплейса - более люботные (заинтересованные) люди. Что это значит. Они раньше других обнаружили интересное новое приложение, оно их привлекло не количеством пользователей
(не сработал стадный инстикт, истикт доверия из-за большого числа пользователей), а само по себе, поэтому и среднее время активности пользователей в начале было больше. Новые пользователи меньше заинтересованы: гораздо сложнее найти новое непопулярное приложение, чем набирающее популярность.
Средяя стоимость заказа не растет возможно из-за того, что в течение года не было никаких явных изменений в категориях товаров, которые могли бы заинтересовать людей и повысить своей стоимостью среднее значение стоимости одного заказа.