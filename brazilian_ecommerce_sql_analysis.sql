/* SQL Analaysis */ 

/*Establish Basline Numbers: Monthly revenue, order count, and average order value (AOV).*/ 
WITH order_revenue AS (
	SELECT
		o.order_id,
        date_trunc('month', o.order_purchase_timestamp)::date AS order_month,
        SUM(oi.price) AS item_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY o.order_id, date_trunc('month', o.order_purchase_timestamp)
)
SELECT
    order_month,
    COUNT(*) AS order_count,
    ROUND(SUM(item_revenue), 2) AS revenue,
    ROUND(AVG(item_revenue), 2) AS avg_order_value
FROM order_revenue
GROUP BY order_month
ORDER BY order_month;
/* Results and Analysis: 
Definitions: 
- Revenue = SUM(order_items.price); excludes freight (shipping)
- Scope: order_stats has to be 'delivered'; month is purchase month. 
- Order-level CTE built first so multi-item orders are not repeated. 

Data Coverage: 
- September 2016 to August 2018. 
	- September - December 2016 has little order counts, indicating incomplete data acquisition. 
- Trend Analysis is filtering between Janurary 2017 - August 2018. 

Findings: 
- Volume of orders grew significantly between Janurary 2017 to October 2017, peaking at 4,478 
  orders while generating gross sales of $648,247.65 	 
- Spike in order and revenue in November 2017, jumping to 7,289 orders and $987,765.37. This 
  might be able to be explained because of black friday. Orders fell back in December (5,513). 
- AOV (average order value) stayed between ~$124 to ~$152 across the entire period, indicating 
  revenue growth largely coming from increase in order_counts rather than more expensive orders. 

Takeaways: 
Order volume and AOV seemed to stablized in 2018, ~6250 and ~$135 respectively. Further analysis 
is needed to see whether customer retention is high, or if new customers are not repeat purchasing. 
Delivery performance and customer satisfaction will be good metrics to use. 
*/ 


/*Delivery Performance Analaysis*/
-- Late-delivery share by purchase month
SELECT
    date_trunc('month', o.order_purchase_timestamp)::date AS order_month,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
             THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_late,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                   THEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date
              END), 1) AS avg_days_late_when_late
FROM orders o
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY 1
ORDER BY 1;

--Late-delivery share by customer state
 -- Query B: late-delivery share by customer state (Jan 2017 - Aug 2018)
SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
             THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_late,
    ROUND(AVG(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                   THEN o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date
              END), 1) AS avg_days_late_when_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY c.customer_state
ORDER BY pct_late DESC;
/* Analysis: 
Findings:
- 6,531 of 96,203 delivered orders arrived after the estimated date, which is aruond 6.8%. This
  number excludes canceled and never-delivered orders. 
- The average return-rate hovers around 3%, with 3 spikes: November 2017 (12.4%), Feburary 2018 (14.1%)
  and March 2018 (19.0%). 
- Northeast region have the highest late-delivery rates: AL (21.5%), MA (17.5%), SE (15.4%), 
  Pl (13.9%) and CE (13.8%). 
- RJ has high percentage of late-delivery orders, even though it is not a northeast state. 
- SP and RJ make up 51% of all late orders as they have the largest volume of delivered-orders as well. 
  SP has low rates of late_orders (4.5%) but has a large volume of orders. 

Limitations: 
- Survivorship bias: canceled and undelivered orders are excluded.

Takeaway:
Northeast region needs more research to find why orders are delayed at a higher percentage than other
regions. 
 */

--Late-delivery across spiked months vs months in each state to check RJ 
SELECT
    c.customer_state,
    CASE WHEN date_trunc('month', o.order_purchase_timestamp)::date
              IN ('2017-11-01','2018-02-01','2018-03-01')
         THEN 'spike_months' ELSE 'other_months' END AS period,
    COUNT(*) AS delivered_orders,
    SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
             THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
                           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
  AND c.customer_state IN ('SP','RJ','MG','BA','RS','PR','SC','CE','ES','PE','GO','DF')
GROUP BY 1, 2
ORDER BY 1, 2;
/* Analysis: 
RJ has a slightly above average late_delivery on non-spiked months, but on spiked-months, it is
noticibly higher at 31.22% of late-delivery orders. 
 */

/* Impact of late orders on satisfaction */ 
--Late vs on-time scores. 
WITH review_per_order AS (
    SELECT DISTINCT ON (order_id)
           order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_creation_date DESC, review_answer_timestamp DESC
)
SELECT
    CASE WHEN o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date
         THEN 'late' ELSE 'on_time' END AS delivery_status,
    COUNT(*) AS orders_with_review,
    ROUND(AVG(r.review_score), 2) AS avg_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_1_star,
    ROUND(100.0 * SUM(CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_4_5_star
FROM orders o
JOIN review_per_order r ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY 1
ORDER BY 1;

--Reviews basked on days late and region. 
WITH review_per_order AS (
    SELECT DISTINCT ON (order_id)
           order_id, review_score
    FROM order_reviews
    ORDER BY order_id, review_creation_date DESC, review_answer_timestamp DESC
),
base AS (
    SELECT
        r.review_score,
        CASE WHEN c.customer_state = 'SP' THEN 'SP' ELSE 'non_SP' END AS region,
        o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date AS days_late
    FROM orders o
    JOIN review_per_order r ON r.order_id = o.order_id
    JOIN customers c        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)
SELECT
    region,
    CASE WHEN days_late <= 0  THEN '1. on time / early'
         WHEN days_late <= 3  THEN '2. 1-3 days late'
         WHEN days_late <= 7  THEN '3. 4-7 days late'
         WHEN days_late <= 14 THEN '4. 8-14 days late'
         ELSE                      '5. 15+ days late' END AS bucket,
    COUNT(*) AS orders_with_review,
    ROUND(AVG(review_score), 2) AS avg_score,
    ROUND(100.0 * SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_1_star
FROM base
GROUP BY 1, 2
ORDER BY 1, 2;
/* Analysis: 
Definitions: 
- SP = Sao Paulo state (largest state, most orders). Segmented because SP had the lowest late rate
  as it closer to the center. 
  
Coverage and Limitations: 
- 68,426 of 96,203 delivered orders (71%) have a review. Response between late and on-time is 
  very similar, sitting at 70% and 71% respectively. 
- Late orders may also have other problems, so we can only have correlational findings. 

Findings:
- On-time orders average 4.29 stars while late orders average 2.27. Late orders were around 8x
  more likely to get a 1 star review. 
- Ratings seem to be non-regional, on-time vs late deliveries have almost identical drops
  between SP and non-SP regions. 
- Ratings from 1-3 day(s) late result in dropping around 1 star, 4-7 day(s) result in another 1.1
  stars, while ratings bottom out near 1.6-7 after 8+ days. 
*/ 

/* Repeat Purchase Analysis*/ 
-- Repeat purchase within 180 days, split by whether first order was late. 
WITH orders_c AS (
    SELECT o.order_id,
           c.customer_unique_id,
           c.customer_state,
           o.order_purchase_timestamp AS purchased_at,
           o.order_status,
           o.order_delivered_customer_date,
           o.order_estimated_delivery_date
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
),
first_orders AS (
    SELECT *
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                                  ORDER BY purchased_at, order_id) AS order_seq
        FROM orders_c
    ) r
    WHERE order_seq = 1
      AND order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND purchased_at >= '2017-01-01'
      AND purchased_at <  '2018-03-01'
),
cohort AS (
    SELECT f.customer_unique_id,
           CASE WHEN f.customer_state = 'SP' THEN 'SP' ELSE 'non_SP' END AS region,
           CASE WHEN f.order_delivered_customer_date::date > f.order_estimated_delivery_date::date
                THEN 'late_first_order' ELSE 'on_time_first_order' END AS first_order_status,
           COUNT(n.order_id) > 0 AS came_back
    FROM first_orders f
    LEFT JOIN orders_c n
           ON n.customer_unique_id = f.customer_unique_id
          AND n.purchased_at::date > f.purchased_at::date
          AND n.purchased_at < f.purchased_at + INTERVAL '180 days'
          AND n.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY f.customer_unique_id, f.customer_state,
             f.order_delivered_customer_date, f.order_estimated_delivery_date
)
SELECT COALESCE(region, 'ALL') AS region,
       first_order_status,
       COUNT(*) AS customers,
       SUM(came_back::int) AS repeat_customers,
       ROUND(100.0 * SUM(came_back::int) / COUNT(*), 2) AS repeat_rate_pct
FROM cohort
GROUP BY GROUPING SETS ((first_order_status), (region, first_order_status))
ORDER BY region NULLS FIRST, first_order_status;
/* Analysis 
Limitations: 
- Excldues customers whose first order was canceled/undelivered.
- 180-day window 

Findings:
- Repeat rate is very low overall, sitting at around 2% (1,101 of 55,196).
- Late first order: 1.61% (59 of 3,664) vs on-time (1,042 of 51,532). There is a difference of 
  around .41%. 
- Region averages were consistent.
- Late orders do not seem to contribute significantly to whether or not customers would order again.  
*/ 


/* Ranking sellers and product categories */ 
-- Ranking sellers by late-delivery rate 
WITH delivered AS (
    SELECT order_id,
           (order_delivered_customer_date::date > order_estimated_delivery_date::date) AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
),
seller_orders AS (                      -- one row per (seller, order)
    SELECT DISTINCT oi.seller_id, d.order_id, d.is_late
    FROM order_items oi
    JOIN delivered d ON d.order_id = oi.order_id
),
seller_stats AS (
    SELECT seller_id,
           COUNT(*) AS orders,
           SUM(is_late::int) AS late_orders,
           ROUND(100.0 * SUM(is_late::int) / COUNT(*), 2) AS pct_late
    FROM seller_orders
    GROUP BY seller_id
    HAVING COUNT(*) >= 50
),
ranked AS (
    SELECT seller_id, orders, late_orders, pct_late,
           RANK() OVER (ORDER BY pct_late DESC, late_orders DESC) AS late_rank,
           COUNT(*) OVER () AS qualifying_sellers
    FROM seller_stats
)
SELECT r.late_rank, r.seller_id, s.seller_state,
       r.orders, r.late_orders, r.pct_late, r.qualifying_sellers
FROM ranked r
JOIN sellers s ON s.seller_id = r.seller_id
WHERE r.late_rank <= 25
ORDER BY r.late_rank;

-- Ranking by worst product categories by late-delivery rate
WITH delivered AS (
    SELECT order_id,
           (order_delivered_customer_date::date > order_estimated_delivery_date::date) AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
),
category_orders AS (                   
    SELECT DISTINCT
           COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
           d.order_id, d.is_late
    FROM order_items oi
    JOIN delivered d  ON d.order_id = oi.order_id
    LEFT JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN product_category_translation t
           ON t.product_category_name = p.product_category_name
),
category_stats AS (
    SELECT category,
           COUNT(*) AS orders,
           SUM(is_late::int) AS late_orders,
           ROUND(100.0 * SUM(is_late::int) / COUNT(*), 2) AS pct_late
    FROM category_orders
    GROUP BY category
    HAVING COUNT(*) >= 50
)
SELECT RANK() OVER (ORDER BY pct_late DESC, late_orders DESC) AS late_rank,
       category, orders, late_orders, pct_late
FROM category_stats
ORDER BY late_rank
LIMIT 25;

/* Analysis: 
Definitions: 
- Rate = late orders / delivered orders containing that seller. An order counts once per
  seller/category. 
- Minimum volume: HAVING COUNT(*) >= 50 delivered orders. 

Limitations:
- Rates not adjusted for spiked vs non-spiked months. 

Findings: 
- Top 25 sellers have late rates of 13.9%-30.1%. The overall late delivery rate was 6.8%
- Three sellers combine high rate and high volume and are clearly beyond chance: 
  rank 5 (MA, 19.0%, 74/389), rank 10 (PR, 17.1%, 42/246), rank 16 (SP, 15.7%, 34/216) 
  = ~2.3% of all late orders.  
- Category differences are small, except with Audio, having 11.85% late orders. 
 */

/* Revenue from sellers in the worst decile of delivery performance*/ 
-- Revenue exposure by seller late-rate decile (decile 1 is worst)
WITH delivered AS (
    SELECT order_id,
           (order_delivered_customer_date::date > order_estimated_delivery_date::date) AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
),
seller_order AS (                          -- one row per (seller, order); no DISTINCT needed
    SELECT oi.seller_id, oi.order_id, d.is_late,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN delivered d ON d.order_id = oi.order_id
    GROUP BY oi.seller_id, oi.order_id, d.is_late
),
seller_agg AS (
    SELECT seller_id,
           COUNT(*) AS orders,
           SUM(is_late::int) AS late_orders,
           SUM(revenue) AS revenue,
           SUM(CASE WHEN is_late THEN revenue ELSE 0 END) AS late_revenue,
           SUM(SUM(revenue)) OVER () AS total_revenue,     -- all sellers, before the filter
           SUM(SUM(is_late::int)) OVER () AS total_late_orders
    FROM seller_order
    GROUP BY seller_id
),
qualified AS (
    SELECT *,
           100.0 * late_orders / orders AS pct_late,
           NTILE(10) OVER (ORDER BY 100.0 * late_orders / orders DESC, late_orders DESC) AS decile
    FROM seller_agg
    WHERE orders >= 50
)
SELECT decile,
       COUNT(*) AS sellers,
       ROUND(MIN(pct_late), 1) AS min_pct_late,
       ROUND(MAX(pct_late), 1) AS max_pct_late,
       SUM(orders) AS orders,
       SUM(late_orders) AS late_orders,
       ROUND(SUM(revenue)) AS revenue,
       ROUND(100.0 * SUM(revenue) / MAX(total_revenue), 1)  AS pct_of_all_revenue,
       ROUND(100.0 * SUM(late_orders) / MAX(total_late_orders), 1) AS pct_of_all_late_orders,
       ROUND(SUM(late_revenue)) AS revenue_on_late_orders
FROM qualified
GROUP BY decile
ORDER BY decile;

-- Same as before, but ranking on non-spike months only. 
WITH delivered AS (
    SELECT order_id,
           (order_delivered_customer_date::date > order_estimated_delivery_date::date) AS is_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
      AND date_trunc('month', order_purchase_timestamp)::date
          NOT IN ('2017-11-01', '2018-02-01', '2018-03-01')
),
seller_order AS (                          -- one row per (seller, order); no DISTINCT needed
    SELECT oi.seller_id, oi.order_id, d.is_late,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN delivered d ON d.order_id = oi.order_id
    GROUP BY oi.seller_id, oi.order_id, d.is_late
),
seller_agg AS (
    SELECT seller_id,
           COUNT(*) AS orders,
           SUM(is_late::int) AS late_orders,
           SUM(revenue) AS revenue,
           SUM(CASE WHEN is_late THEN revenue ELSE 0 END) AS late_revenue,
           SUM(SUM(revenue)) OVER () AS total_revenue,     -- all sellers, before the filter
           SUM(SUM(is_late::int)) OVER () AS total_late_orders
    FROM seller_order
    GROUP BY seller_id
),
qualified AS (
    SELECT *,
           100.0 * late_orders / orders AS pct_late,
           NTILE(10) OVER (ORDER BY 100.0 * late_orders / orders DESC, late_orders DESC) AS decile
    FROM seller_agg
    WHERE orders >= 50
)
SELECT decile,
       COUNT(*) AS sellers,
       ROUND(MIN(pct_late), 1) AS min_pct_late,
       ROUND(MAX(pct_late), 1) AS max_pct_late,
       SUM(orders) AS orders,
       SUM(late_orders) AS late_orders,
       ROUND(SUM(revenue)) AS revenue,
       ROUND(100.0 * SUM(revenue) / MAX(total_revenue), 1)  AS pct_of_all_revenue,
       ROUND(100.0 * SUM(late_orders) / MAX(total_late_orders), 1) AS pct_of_all_late_orders,
       ROUND(SUM(late_revenue)) AS revenue_on_late_orders
FROM qualified
GROUP BY decile
ORDER BY decile;
/* Analysis: 
 Definitions
 - Second query repeats analysis excluding November 2017, Feburary 2018, and March 2018. 
 
 Findings:
 - Worst decile has around 15 Worst decile: 15.2% late (751/4,929) vs 6.8% overall and 0.9% 
   for the best decile. Revenue $618.5K (4.7% of total), of which $105.5K (17.1%) is on 
   late orders; ~0.8% of total marketplace revenue.
 - They hold 11.5% of all late orders. Bringing them to the average rate would remove 
   ~416 late orders (~6% of all late orders).
 - Decile 3 (8.0-9.6% late, 12,245 orders) holds more late orders (16.5%) than decile 1 
   because of volume; rate alone is an incomplete prioritization rule. 
 - Robust to spike months: excluding them, decile 1 is 11.6% late vs 4.5% baseline 
   (2.6x) and holds 11.6% of late orders. Seller overlap between the two rankings not checked.
*/ 
