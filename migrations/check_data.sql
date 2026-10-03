-- Каждый пользователь имеет одинаковое количество измерений.

SELECT Users.name, count(users.id) as batches_num FROM Users INNER JOIN Logs ON 
Logs.user_id = users.id GROUP BY Users.name;

-- У нас нет пустых пачек измерения

SELECT count(Logs.id) as empty_batches_num FROM Logs LEFT JOIN (SELECT Parameters.log_id FROM Parameters GROUP BY Parameters.id) as log_ids ON log_ids.log_id = Logs.id WHERE log_ids.log_id IS NULL;

-- Каждая пачка измерений содедержит полное количеситво параметров

SELECT *, 
CASE 
	WHEN name = 'ДМК' THEN actual_params <@ array[1,2,3,4,5] AND actual_params @> array[1,2,3,4,5]
	WHEN name = 'ВР' THEN actual_params <@ array[1,2,3,4,6] AND actual_params @> array[1,2,3,4,6]
	ELSE false
	END as batch_is_full
FROM 
(SELECT Parameters.log_id as log_id, array_agg(Parameters.param_id) as actual_params FROM Parameters GROUP BY log_id) as t1
JOIN 
(SELECT Logs.id as id, Equipments.name as name FROM Equipments JOIN Logs ON Equipments.id = Logs.equipment_id) as t2 ON t1.log_id = t2.id;

-- Все значения который сформировал корректны и в рамках нужного нам диаппазонов?
SELECT * FROM(
	SELECT Parameters.id as parameters_id, Parameters.param_value, (Parameters.param_value <= 58 AND Parameters.param_value >= -58) as is_rigth FROM Parameters
	WHERE Parameters.param_id = 2 
	
	UNION 
	
	SELECT Parameters.id as parameters_id, Parameters.param_value, (Parameters.param_value <= 900 AND Parameters.param_value >= 500) as is_rigth FROM Parameters 
	WHERE Parameters.param_id = 3
	
	UNION 
	
	SELECT Parameters.id as parameters_id, Parameters.param_value, (Parameters.param_value <= 59 AND Parameters.param_value >= 0) as is_rigth FROM Parameters 
	WHERE Parameters.param_id = 4
	
	UNION
	
	SELECT Parameters.id as parameters_id, Parameters.param_value, (Parameters.param_value <= 15 AND Parameters.param_value >= 0) as is_rigth FROM Parameters 
	WHERE Parameters.param_id = 5
	
	UNION
	
	SELECT Parameters.id as parameters_id, Parameters.param_value, (Parameters.param_value <= 150 AND Parameters.param_value >= 0) as is_rigth FROM Parameters 
	WHERE Parameters.param_id = 6
	
	UNION
	SELECT Parameters.id as parameters_id, Parameters.param_value, false  as is_rigth FROM Parameters
	WHERE Parameters.param_id IS NULL OR Parameters.param_id NOT BETWEEN 1 AND 6
) WHERE NOT is_rigth;

-- Все единицы измерения верны и корректны по отношению к указанным параметрам?

SELECT id, log_id, parameter_name, units_id, unit_name, is_unit_correct
FROM 
(
    SELECT p.id,
           p.log_id,
           p.units_id,
           coalesce(t.name, 'Неизвестный тип param_id=' || p.param_id) AS parameter_name,
           coalesce(u.name, 'Неизвестная единица units_id=' || p.units_id) AS unit_name,
           CASE 
               WHEN p.param_id = 1 THEN p.units_id in (1)
               WHEN p.param_id = 2 THEN p.units_id in (3)
               WHEN p.param_id = 3 THEN p.units_id in (2)
               WHEN p.param_id = 4 THEN p.units_id in (4)
               WHEN p.param_id = 5 THEN p.units_id in (5)
               WHEN p.param_id = 6 THEN p.units_id in (1)
               ELSE false
           END AS is_unit_correct
    FROM Parameters p
    LEFT JOIN Types_parameters  t ON t.id = p.param_id
    LEFT JOIN Units_measurement u ON u.id = p.units_id
)
WHERE NOT is_unit_correct
ORDER BY log_id, id;


	



