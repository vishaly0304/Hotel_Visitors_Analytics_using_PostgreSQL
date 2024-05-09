----Hotel Visitors Analytics Using PostgreSQL-----

CREATE TABLE sales (
  "customer_id" VARCHAR(1),
  "order_date" DATE,
  "product_id" INTEGER
);

INSERT INTO sales
  ("customer_id", "order_date", "product_id")
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');

select * from sales;

----------------------------------------------------------------------------------------------------

CREATE TABLE menu (
  "product_id" INTEGER,
  "product_name" VARCHAR(50),
  "price" INTEGER
);

INSERT INTO menu
  ("product_id", "product_name", "price")
VALUES
  ('1', 'chicken vade', '100'),
  ('2', 'fish fry', '150'),
  ('3', 'veg thali', '120');

select * from menu;

----------------------------------------------------------------------------------------------------

CREATE TABLE members (
  "customer_id" VARCHAR(1),
  "join_date" DATE
);

INSERT INTO members
  ("customer_id", "join_date")
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
  
select * from members;

----------------------------------------------------------------------------------------------------
-- Q1) what is the total amount each customer spend at the restaurant?

select 	sales.customer_id as customer_name,
		sum(menu.price) as total_amount_spend
from sales
		left join menu on sales.product_id=menu.product_id
group by sales.customer_id
order by sales.customer_id;

----------------------------------------------------------------------------------------------------
-- Q2) How many days each customer visited the restaurant?

select 	customer_id as customer_name,
		count(distinct(order_date)) as customer_visit_count
from sales
group by customer_id
order by customer_id;

----------------------------------------------------------------------------------------------------
-- Q3) what is the first item from the menue purchased by each customer?

select 	customer_name,
		product_name 
from(
	select 	sales.customer_id as customer_name,
			menu.product_name,
			row_number() over (partition by sales.customer_id order by sales.order_date asc) as rn	
	from sales
	left join menu on sales.product_id=menu.product_id
	)x
where rn=1;

----------------------------------------------------------------------------------------------------
-- Q4) What is the most purchased item on the menu and how many times was it purchased by all customers?

select 	menu.product_name as most_purchased_item,
		count(sales.product_id) as count_of_most_purchased_item
from sales
	left join menu on sales.product_id=menu.product_id
group by menu.product_name
order by count_of_most_purchased_item desc
limit 1;

----------------------------------------------------------------------------------------------------
-- Q5) Which item was the most popular for each customer?

with most_popular_cust as (
	select 	sales.customer_id as customer_name,
			menu.product_name ,
			count(menu.product_name) as count_of_product_buy,
			dense_rank() over(partition by sales.customer_id order by count(sales.customer_id) desc) as rn
	from sales
	left join menu on sales.product_id=menu.product_id
	group by sales.customer_id ,menu.product_name
	order by sales.customer_id
	)
select	customer_name,
		product_name,
		count_of_product_buy
from most_popular_cust
where rn=1;

----------------------------------------------------------------------------------------------------
-- Q6) Which item was purchased first by the customer after they became a member?

with cust_after_member as (
	select 	members.customer_id,
			sales.product_id,
			row_number() over (partition by members.customer_id order by sales.order_date )as rn
	FROM members
	INNER JOIN sales ON members.customer_id = sales.customer_id 
					AND sales.order_date > members.join_date
)

select  cust_after_member.customer_id as customer_name,
		menu.product_name
from cust_after_member
left join menu on cust_after_member.product_id=menu.product_id
where cust_after_member.rn = 1
order by cust_after_member.customer_id asc;	

----------------------------------------------------------------------------------------------------
-- Q7) Which item was purchased just before the customer became a member?

with purchased_item_before_member as(
	select 	members.customer_id,
			sales.product_id,
			row_number() over(partition by members.customer_id order by sales.order_date desc ) as rn
	from members
	inner join sales on members.customer_id=sales.customer_id
					and sales.order_date < members.join_date
	)
select 	purchased_item_before_member.customer_id as customer_name,
		menu.product_name
from purchased_item_before_member
left join menu on purchased_item_before_member.product_id=menu.product_id
where rn=1
order by purchased_item_before_member.customer_id asc;

----------------------------------------------------------------------------------------------------
-- Q8) What is the total items and amount spent for each member before they became a member?

select 	sales.customer_id as customer_name,
		count(sales.product_id) as total_items,
		sum(menu.price) as amount_spend
from sales
inner join members on sales.customer_id=members.customer_id
				 and sales.order_date < members.join_date
left join menu on sales.product_id=menu.product_id
group by sales.customer_id
order by sales.customer_id;

----------------------------------------------------------------------------------------------------
-- Q9) If each 50 spent equates to 10 points and fish fry has a 3x points multiplier how many points would each customer have?

with points_table as (
	select 	menu.product_id,
			case when product_id =2 then price * 30
				else price * 10
			end as points
	from menu
	)
select 	sales.customer_id as customer_name,
		sum(points_table.points) as customer_total_points
from sales
left join points_table on sales.product_id = points_table.product_id
group by sales.customer_id
order by sales.customer_id;

----------------------------------------------------------------------------------------------------
-- Q10) In the first week after a customer joins the program (including their join date) they earn 3x points on all items, not just fish fry -how many points do customer A and B have at the end of January?

with date_table as (
	select 	customer_id, 
			join_date, 
			join_date + 6 as valid_date, 
			(DATE_TRUNC('month', join_date) + interval '1 month' - interval '1 day' )::date as last_date
	from members
	)
select	sales.customer_id as customer_name,
		sum(case when menu.product_name = 'fish fry' then 3 * 10 * menu.price
				 when sales.order_date between date_table.join_date and date_table.valid_date then 3 * 10 * menu.price
				 else 10 * menu.price 
			end) as customer_total_points
from sales
inner join date_table on sales.customer_id=date_table.customer_id
					  and sales.order_date >= date_table.join_date 
					  and sales.order_date <= date_table.last_date
left join menu on sales.product_id = menu.product_id
group by sales.customer_id
order by sales.customer_id;
-------------------------------------------------------------------------------------------------------------