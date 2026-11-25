-- скрипт для закрытия разницы между моим решениями
do $$
begin
    create table public.calc_temperature_correction
    (temperature numeric(8,2) not null primary key,
        correction numeric(8,2) not null);

    insert into public.calc_temperature_correction(temperature, correction)
    values (0, 0), (5, 0.5), (10, 1), (15, 1),
           (20, 1.5), (25, 2), (30, 3.5), (40, 4.5);

    create type public.interpolation_type as
    (x0 numeric(8,2), x1 numeric(8,2),
     y0 numeric(8,2),y1 numeric(8,2));

    create function public.fn_calc_interpolation( par_x numeric,
        par_interpolation public.interpolation_type)
    returns numeric
    language plpgsql
    as $func$
    begin
        if par_interpolation.x1 = par_interpolation.x0 then
            return par_interpolation.y0;
        end if;

        return round(
            par_interpolation.y0
            + (par_x - par_interpolation.x0)
              * (par_interpolation.y1 - par_interpolation.y0)
              / (par_interpolation.x1 - par_interpolation.x0),
            2
        );
    end;
    $func$;
end $$;
