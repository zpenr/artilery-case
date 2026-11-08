select 'Тест 1. ДМК' as "Тест";

do $$
declare
    v_tt text;
begin
    call calc_meteo_bulletin(
        row(100, 25, 765, 15, 6, null)::input_params_type,
        1
    );

    select tt into v_tt
    from calc_meteo_result
    where height = 200;

    if v_tt is distinct from '11' then
        raise exception 'Тест 1: ожидалось TT=11 на 200 м, получено %', v_tt;
    end if;
end $$;

select * from calc_meteo_result order by height;

select 'Тест 2. ДМК' as "Тест";

do $$
declare
    v_tt text;
begin
    call calc_meteo_bulletin(
        row(100, 3, 750, 0, 0, null)::input_params_type,
        1
    );

    select tt into v_tt
    from calc_meteo_result
    where height = 200;

    if v_tt is distinct from '62' then
        raise exception 'Тест 2: ожидалось TT=62 на 200 м, получено %', v_tt;
    end if;
end $$;

select * from calc_meteo_result order by height;

select 'Тест 3. ВР' as "Тест";

do $$
declare
    v_hh text;
    v_cc text;
begin
    call calc_meteo_bulletin(
        row(100, 15, 750, 10, null, 80)::input_params_type,
        2
    );

    select hh, cc into v_hh, v_cc
    from calc_meteo_result
    where height = 200;

    if v_hh is distinct from '10' or v_cc is distinct from '07' then
        raise exception 'Тест 3: ожидалось HH=10, CC=07 на 200 м, получено %/%', v_hh, v_cc;
    end if;
end $$;

select * from calc_meteo_result order by height;
