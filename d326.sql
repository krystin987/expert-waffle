-- B.
CREATE OR REPLACE FUNCTION calculate_rental_duration(rental_date DATE, return_date DATE)
RETURNS integer AS $$
BEGIN
	
	IF return_date IS null THEN
		RETURN (current_date - rental_death);
	ELSE
		RETURN(return_date - rental_date);
	END IF;
END;
$$ language plpgsql;

SELECT f.film_id, f.title, AVG(calculate_rental_duration(r.rental_date::Date, r.return_date::date)) AS avg_rental_duration
FROM film f
JOIN rental r ON f.film_id = r.rental_id
GROUP BY f.film_id, f.title;

-- C.
CREATE TABLE detailed_table(
    film_id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    genre VARCHAR(50) NOT NULL,
    release_year INT,
    rental_rate NUMERIC(10, 2) NOT NULL,
    total_rentals INT NOT NULL,
    total_revenue NUMERIC(10, 2) NOT NULL,
    avg_rental_duration NUMERIC(10, 2),
    top_actor TEXT
)
CREATE TABLE summary_table(
    genre VARCHAR(50) PRIMARY KEY,
    total_rentals INT NOT NULL,
    total_revenue NUMERIC(10,2) NOT NULL,
    avg_rental_rate NUMERIC(10,2),
    most_popular_film VARCHAR(255),
    top_actor TEXT
)
-- D.
SELECT
	f.film_id as film_id,
	f.title AS title,
	c.name AS genre,
	f.release_year AS release_year,
	f.rental_rate AS rental_rate,
	COUNT(r.rental_id) AS total_rentals,
	SUM(f.rental_rate) AS total_revenue,
	AVG(DATE_PART('day', COALESCE(r.return_date, CURRENT_DATE) - r.rental_date)) AS avg_rental_duration,
	STRING_AGG(a.first_name || ' ' || a.last_name, ',') AS top_actor

FROM
	film f
JOIN
	inventory i ON f.film_id = i.film_id
JOIN
	rental r ON i.inventory_id = r.inventory_id
LEFT JOIN
	film_actor fa ON f.film_id = fa.film_id
LEFT JOIN
	actor a ON fa.actor_id = a.actor_id
JOIN
	film_category fc ON f.film_id = fc.film_id
JOIN
	category c ON fc.category_id = c.category_id
GROUP BY
	f.film_id, f.title, c.name, f.release_year, f.rental_rate
ORDER BY
	total_rentals DESC;

-- E.
CREATE OR REPLACE FUNCTION update_summary_table()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the genre already exists in the summary table
    IF EXISTS (SELECT 1 FROM summary_table WHERE genre = NEW.genre) THEN
        -- Update the existing row for the genre
        UPDATE summary_table
        SET
            total_rentals = total_rentals + NEW.total_rentals,
            total_revenue = total_revenue + NEW.total_revenue,
            avg_rental_rate = (
                SELECT (total_revenue + NEW.total_revenue) / (total_rentals + NEW.total_rentals)
                FROM summary_table WHERE genre = NEW.genre
            ),
            most_popular_film = CASE 
                WHEN NEW.total_rentals > total_rentals THEN NEW.title 
                ELSE most_popular_film 
            END
        WHERE genre = NEW.genre;
    ELSE
        -- Insert a new row if the genre does not exist
        INSERT INTO summary_table (genre, total_rentals, total_revenue, avg_rental_rate, most_popular_film, top_actor)
        VALUES (
            NEW.genre,
            NEW.total_rentals,
            NEW.total_revenue,
            NEW.rental_rate,
            NEW.title,
            NEW.top_actor
        );
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

--  create trigger for E
CREATE TRIGGER trigger_update_summary_table
AFTER INSERT ON detailed_table
FOR EACH ROW
EXECUTE FUNCTION update_summary_table();

-- data for E
INSERT INTO detailed_table (title, genre, release_year, rental_rate, total_rentals, total_revenue, avg_rental_duration, top_actor)
VALUES ('Action Hero 1', 'Action', 2022, 4.99, 150, 748.50, 3.5, 'John Doe');

INSERT INTO detailed_table (title, genre, release_year, rental_rate, total_rentals, total_revenue, avg_rental_duration, top_actor)
VALUES ('Comedy Night', 'Action', 2021, 3.99, 200, 798.00, 4.0, 'Jane Smith');

INSERT INTO detailed_table (title, genre, release_year, rental_rate, total_rentals, total_revenue, avg_rental_duration, top_actor)
VALUES ('Funny Times', 'Comedy', 2023, 5.49, 120, 658.80, 4.1, 'Jane Doe');


-- F.
CREATE OR REPLACE PROCEDURE refresh_report_tables()
LANGUAGE plpgsql
AS $$
BEGIN
      TRUNCATE TABLE detailed_table RESTART IDENTITY;
      TRUNCATE TABLE summary_table RESTART IDENTITY;

      INSERT INTO detailed_table(film_id, title, genre, release_year, rental_rate, total_rentals, total_revenue, avg_rental_duration, top_actor)
      SELECT
      f.film_id as film_id,
      f.title AS title,
      c.name AS genre,
      f.release_year AS release_year,
      f.rental_rate AS rental_rate,
      COUNT(r.rental_id) AS total_rentals,
      SUM(f.rental_rate) AS total_revenue,
      AVG(DATE_PART('day', COALESCE(r.return_date, CURRENT_DATE) - r.rental_date)) AS avg_rental_duration,
      STRING_AGG(a.first_name || ' ' || a.last_name, ',') AS top_actor

      FROM
            film f
      JOIN
            inventory i ON f.film_id = i.film_id
      JOIN
            rental r ON i.inventory_id = r.inventory_id
      LEFT JOIN
            film_actor fa ON f.film_id = fa.film_id
      LEFT JOIN
            actor a ON fa.actor_id = a.actor_id
      JOIN
            film_category fc ON f.film_id = fc.film_id
      JOIN
            category c ON fc.category_id = c.category_id
      GROUP BY
            f.film_id, f.title, c.name, f.release_year, f.rental_rate;

      INSERT INTO summary_table(genre, total_rentals, total_revenue, avg_rental_rate, most_popular_film, top_actor)
      SELECT
            genre,
            SUM(total_rentals) AS total_rentals,
            SUM(total_revenue) AS total_revenue,
            AVG(rental_rate) AS avg_rental_rate,
            MAX(title) AS most_popular_film,
            STRING_AGG(DISTINCT top_actor, ',') AS top_actor
      FROM
            detailed_table
      GROUP BY
            genre;
END;
$$
            
SELECT
      genre,
      SUM(total_rentals) AS total_rentals,
      SUM(total_revenue) AS total_revenue
FROM
      detailed_table
GROUP BY
      genre;


-- CALL refresh_report_tables();
-- CALL update_summary_table();

