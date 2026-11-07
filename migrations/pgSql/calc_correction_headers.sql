-- Миграция: вынос header_values из calc_correction_types
do $$
begin

	create sequence calc_correction_headers_seq;
	create table calc_correction_headers
	(id integer primary key not null default nextval('public.calc_correction_headers_seq'),
		header_values integer[] not null);

	insert into calc_correction_headers(header_values)
	select distinct header_values
	from calc_correction_types
	where header_values is not null;

	alter table calc_correction_types add column header_id integer;

	update calc_correction_types as t
	set header_id = h.id
	from calc_correction_headers as h where h.header_values = t.header_values;

	alter table calc_correction_types add constraint fk_calc_correction_types_header
		foreign key (header_id) references calc_correction_headers(id);

	alter table calc_correction_types drop column header_values;

end $$;
