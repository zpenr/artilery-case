--Тестирование
DO $$
BEGIN
	BEGIN
		CREATE TYPE test_result AS (
			x decimal(7,2),
			calced_y decimal(7,2),
			target_y decimal(7,2),
			is_pass bool		
		);
		EXCEPTION
	        WHEN duplicate_object THEN NULL;
	END;
END $$;

CREATE OR REPLACE FUNCTION tests()
RETURNS SETOF test_result AS $$
DECLARE
    interpol decimal(7,2);
BEGIN
    -- Тесты из ТЗ
    interpol := interpolation(23, find_value(1,23));
    RETURN NEXT ROW(23, interpol, 1.8 , interpol=1.8)::test_result;
    interpol := interpolation(25, find_value(1,25));
    RETURN NEXT ROW(25, interpol, 2, interpol=2)::test_result;
    interpol := interpolation(3, find_value(1,3));
    -- Свои тесты
    RETURN NEXT ROW(3 , interpol, 0.5, interpol=0.5)::test_result;
    interpol := interpolation(12, find_value(1,12));
    RETURN NEXT ROW(12, interpol, 1 , interpol=1)::test_result;
    interpol := interpolation(-5, find_value(1,-5));
    RETURN NEXT ROW(-5, interpol, 0 , interpol=0)::test_result;
    RETURN;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM tests();