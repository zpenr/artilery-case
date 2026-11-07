do $$
begin
    create type input_params_type as
    (height numeric(8,2), temperature numeric(8,2),
        pressure numeric(8,2), wind_direction numeric(8,2),
        wind_speed numeric(8,2), bullet_range numeric(8,2));

    create or replace function correction_value(p_type_id integer, p_height integer, p_column integer)
    returns integer
    language sql
    as $func$
        select c.row_values[u.i]
        from calc_correction c
        join calc_correction_types t on t.id = c.type_id
        left join calc_correction_types p on p.id = t.parent_id
        join calc_correction_headers h on h.id = coalesce(t.header_id, p.header_id)
        join lateral unnest(h.header_values) with ordinality as u(value, i) on u.value = p_column
        where c.type_id = p_type_id
        and c.height_id = p_height
        limit 1;
    $func$;

    create or replace function wind_speed(p_type_id integer, p_height integer, p_value numeric)
    returns integer
    language sql
    as $func$
        select c.row_values[headers.i]
        from calc_correction c
        join calc_correction_heights hh on hh.id = c.height_id
        join calc_correction_types t on t.id = c.type_id
        join calc_correction_headers h on h.id = t.header_id
        join lateral unnest(h.header_values) with ordinality as headers(value, i) on true
        where c.type_id = p_type_id
        and hh.height = p_height
        order by abs(headers.value - p_value), headers.value
        limit 1;
    $func$;

create procedure public.calc_meteo_bulletin(p public.input_params_type,equipment_id int)
language plpgsql
as $proc$
declare
    v_delta integer;
    v_temp_type integer;
    v_speed_type integer;
    v_dir_type integer;
    v_wind_value numeric;
    v_wind_zero boolean;
begin

    v_delta := round(p.temperature + fn_calc_temperature_interpolation(p.temperature) - 15.9)::integer;

    if equipment_id = 1 then
        v_temp_type := case when v_delta < 0 then 8 else 9 end;
        v_speed_type := 6;
        v_dir_type := 7;
        v_wind_value := coalesce(p.wind_speed, 0);
        v_wind_zero := v_wind_value < 3;
    else
        v_temp_type := case when v_delta < 0 then 8 else 9 end;
        v_speed_type := 4;
        v_dir_type := 5;
        v_wind_value := coalesce(p.bullet_range, 0);
        v_wind_zero := v_wind_value < 40;
    end if;

    create temp table if not exists calc_meteo_result(height integer,tt text,hh text,cc text);

    truncate calc_meteo_result;

    insert into calc_meteo_result(height, tt, hh, cc)
    select
        h.height,
        lpad((case
                when v_delta < 0 then 50 + abs(x.corr)
                else x.corr end)::text,2,'0') as tt,
        case
            when v_wind_zero then '00'
            else lpad(
                mod(coalesce(p.wind_direction, 0)::integer +
                 (select c.row_values[1]
                       from calc_correction c
                       where c.type_id = v_dir_type
                       and c.height_id = h.id),
                    60)::text,2,'0')
        end as hh,
        case
            when v_wind_zero then '00'
            else lpad(wind_speed(v_speed_type, h.height, v_wind_value)::text,2,'0')
        end as cc
    from calc_correction_heights h
    cross join lateral (
        select
            coalesce(correction_value(v_temp_type, h.id, (abs(v_delta) / 10) * 10), 0)
            + coalesce(correction_value(v_temp_type, h.id, abs(v_delta) % 10
            ), 0) as corr) x order by h.height;
end;
$proc$;

end $$;