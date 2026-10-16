DO $$
BEGIN 
    BEGIN
        CREATE TYPE calc_point AS (
            x0 decimal(7,2),
            y0 decimal(7,2),
            x1 decimal(7,2),
            y1 decimal(7,2)
        );
    EXCEPTION
        WHEN duplicate_object THEN NULL;
    END;
END $$;

CREATE OR REPLACE FUNCTION find_value(
    p_table_id int, 
    p_temperature decimal(7,2)
)
RETURNS calc_point AS $$
DECLARE 
	left_x  decimal(7,2);
    left_y  decimal(7,2);
    right_x decimal(7,2);
    right_y decimal(7,2);
BEGIN
		-- Сначала смотрим случай если у нас значение попадает в диапазон
		SELECT 
	        c.min_val,
	        c.max_val,
	        cc.val
	    INTO left_x, right_x, left_y
	    FROM calc_columns AS c
	    JOIN calc_cells AS cc ON cc.col_id = c.id
	    WHERE c.table_id = p_table_id 
	      AND cc.row_id = 1
	      AND c.min_val IS NOT NULL 
	      AND c.max_val IS NOT NULL
	      AND p_temperature >= c.min_val 
	      AND p_temperature <= c.max_val
	    LIMIT 1;

		-- Если значение попало в диапазон возвращаем точки
		IF left_x IS NOT NULL THEN
	        right_y := left_y;
	        RETURN ROW(left_x, left_y, right_x, right_y)::calc_point;
	    END IF;

		-- Находим первую точку
        SELECT 
            COALESCE(c.max_val, c.min_val) AS x,
            cc.val AS y
		INTO left_x, left_y
        FROM calc_columns c
        JOIN calc_cells cc ON cc.col_id = c.id
        WHERE c.table_id = p_table_id 
          AND cc.row_id = 1
          AND COALESCE(c.max_val, c.min_val) <= p_temperature
        ORDER BY COALESCE(c.max_val, c.min_val) DESC
        LIMIT 1;

		-- Находим 2 точку
        SELECT 
            COALESCE(c.min_val, c.max_val) AS x,
            cc.val AS y
		INTO right_x, right_y
        FROM calc_columns c
        JOIN calc_cells cc ON cc.col_id = c.id
        WHERE c.table_id = p_table_id 
          AND cc.row_id = 1
          AND COALESCE(c.min_val, c.max_val) >= p_temperature
        ORDER BY COALESCE(c.min_val, c.max_val) ASC
        LIMIT 1;

		-- Проверяем значения на NULL, если NULL значит нет верзнего или нижнего значения в таблице
		IF right_x IS NULL THEN
        	right_x := p_temperature;
        	right_y := left_y;
   		END IF;

		IF left_x IS NULL THEN
	        left_x := p_temperature;
	        left_y := right_y;
	    END IF;

		-- Возвращаем
		RETURN ROW(left_x, left_y, right_x, right_y)::calc_point;
		
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION interpolation(x decimal(7,2), interpol_vals calc_point)
RETURNS decimal(7,2) AS $$
DECLARE 
	dx decimal(7,2);
	dy decimal(7,2);
BEGIN 
	dx := interpol_vals.x1 - interpol_vals.x0;
	dy := interpol_vals.y1 - interpol_vals.y0;

	IF dx = 0 OR dx IS NULL THEN
		RETURN COALESCE(interpol_vals.y0, interpol_vals.y1);
	END IF;
	
	BEGIN
		RETURN (interpol_vals.y0 + ((x - interpol_vals.x0) * dy) / dx)::decimal(7,2);
	EXCEPTION
		WHEN division_by_zero THEN
			RETURN COALESCE(interpol_vals.y0, interpol_vals.y1);
	END;
END;
$$ LANGUAGE plpgsql;
