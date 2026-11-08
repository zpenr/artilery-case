DO $$
BEGIN
    CREATE TYPE input_params_type AS (
        height numeric(8, 2),
        temperature numeric(8, 2),
        pressure numeric(8, 2),
        wind_direction numeric(8, 2),
        wind_speed numeric(8, 2),
        bullet_range numeric(8, 2)
);
    CREATE OR REPLACE FUNCTION correction_value (p input_params_type, p_type_id integer, p_height integer, p_column integer )
        RETURNS integer
        LANGUAGE sql
        AS $func$
        SELECT
            c.row_values[u.i]
        FROM
            calc_correction c
            JOIN calc_correction_types t ON t.id = c.type_id
            LEFT JOIN calc_correction_types pt ON pt.id = t.parent_id
            JOIN calc_correction_headers h ON h.id = coalesce (
                t.header_id,
                pt.header_id )
            JOIN LATERAL unnest (
                h.header_values )
            WITH ORDINALITY AS u ( value, i
            ) ON u.value = p_column
        WHERE
            c.type_id = p_type_id
            AND c.height_id = p_height LIMIT 1;
    $func$;
    CREATE OR REPLACE FUNCTION wind_speed (p input_params_type, p_type_id integer, p_height integer )
        RETURNS integer
        LANGUAGE plpgsql
        AS $func$
DECLARE
    v_val numeric;
BEGIN
    IF p_type_id IN (4, 5) THEN
        v_val := coalesce(p.bullet_range, 0);
    ELSE
        v_val := coalesce(p.wind_speed, 0);
    END IF;
    RETURN (
        SELECT
            c.row_values[headers.i]
        FROM
            calc_correction c
            JOIN calc_correction_heights hh ON hh.id = c.height_id
            JOIN calc_correction_types t ON t.id = c.type_id
            JOIN calc_correction_headers h ON h.id = t.header_id
            JOIN LATERAL unnest(h.header_values)
            WITH ORDINALITY AS headers (value, i) ON TRUE
        WHERE
            c.type_id = p_type_id
            AND hh.height = p_height
        ORDER BY
            abs(headers.value - v_val),
            headers.value
        LIMIT 1);
END;
    $func$;
    CREATE PROCEDURE public.calc_meteo_bulletin (p public.input_params_type, equipment_id int )
    LANGUAGE plpgsql
    AS $proc$
DECLARE
    v_delta integer;
    v_temp_type integer;
    v_speed_type integer;
    v_dir_type integer;
    v_wind_value numeric;
    v_wind_zero boolean;
BEGIN
    v_delta := round(p.temperature + fn_calc_temperature_interpolation (p.temperature) - get_constant ('TEMPERATURE'))::integer;
    IF equipment_id = 1 THEN
        v_temp_type := CASE WHEN v_delta < 0 THEN
            8
        ELSE
            9
        END;
        v_speed_type := 6;
        v_dir_type := 7;
        v_wind_value := coalesce(p.wind_speed, 0);
        v_wind_zero := v_wind_value < get_constant ('WIND_ZERO_DMK');
    ELSE
        v_temp_type := CASE WHEN v_delta < 0 THEN
            8
        ELSE
            9
        END;
        v_speed_type := 4;
        v_dir_type := 5;
        v_wind_value := coalesce(p.bullet_range, 0);
        v_wind_zero := v_wind_value < get_constant ('RANGE_ZERO_VR');
    END IF;
    CREATE temp TABLE IF NOT EXISTS calc_meteo_result (
        height integer,
        tt text,
        hh text,
        cc text
    );
    TRUNCATE calc_meteo_result;
    INSERT INTO calc_meteo_result (height, tt, hh, cc)
    SELECT
        h.height,
        lpad((
            CASE WHEN v_delta < 0 THEN
                50 + abs(x.corr)
            ELSE
                x.corr
            END)::text, 2, '0') AS tt,
        CASE WHEN v_wind_zero THEN
            '00'
        ELSE
            lpad(mod(coalesce(p.wind_direction, 0)::integer + (
                        SELECT
                            c.row_values[1]
                        FROM calc_correction c
                        WHERE
                            c.type_id = v_dir_type
                            AND c.height_id = h.id), 60)::text, 2, '0')
        END AS hh,
        CASE WHEN v_wind_zero THEN
            '00'
        ELSE
            lpad(wind_speed (p, v_speed_type, h.height)::text, 2, '0')
        END AS cc
    FROM
        calc_correction_heights h
        CROSS JOIN LATERAL (
            SELECT
                coalesce(correction_value (p, v_temp_type, h.id, (abs(v_delta) / 10) * 10), 0) + coalesce(correction_value (p, v_temp_type, h.id, abs(v_delta) % 10), 0) AS corr) x
    ORDER BY
        h.height;
END;
    $proc$;
END
$$;

