
# ALTER DATABASE ufo RENAME TO transacciones;
# CREATE DATABASE ufo WITH TEMPLATE transacciones OWNER felipe;

-- QUITAMOS LA TABLA ACTUAL
DROP TABLE IF EXISTS clean.ufo CASCADE;

-- CREAMOS LA TABLA SUCIA
CREATE TABLE dirty.raw_input (
	date_time varchar,
	city varchar,
	state varchar,
	shape varchar,
	duration varchar,
	summary varchar,
	posted varchar,
	description_url varchar,
	id varchar,
	origin varchar,
	long_description varchar
);

-- SUBIMOS LOS DATOS A LA TABLA SUCIA
psql -d ufo -f load_raw_input.sql


-- CREAMOS LA TABLA LIMPIA DE UFO
CREATE TABLE clean.ufo (
	origin varchar,
	id varchar,
	date_time timestamp,
	year smallint,
	month smallint,
	day smallint,
	weekday smallint,
	city varchar,
	state varchar,
	shape varchar,
	duration varchar,
	number float,
	units varchar,
	seconds bigint,
	summary varchar,
	posted timestamp,
	description_url varchar,
	long_description varchar
);

-- CREAMOS LA PARTICIÓN
ls datos/ufo| grep ndxe | awk '{gsub(/[^0-9]/,"",$0); $0=substr($0,1,4); if($0=="") $0="0000"; print}' | sort | uniq \
| while read a;
do
echo "CREATE TABLE clean.ufo_$a (CONSTRAINT partition_date_range CHECK (date_time >= '$a-01-01'::date AND date_time <= '$a-12-31'::date)) INHERITS (clean.ufo);"
done > create_ufo_partition.sql
echo "CREATE TABLE clean.ufo_overflow () INHERITS (clean.ufo);" >> create_ufo_partition.sql

psql -d ufo -f create_ufo_partition.sql

-- AHORA LOS TRIGGERS
echo "CREATE OR REPLACE FUNCTION ufo_insert()
RETURNS TRIGGER AS \$f\$
BEGIN
	CASE" > create_ufo_partition_trigger.sql

ls datos/ufo| grep ndxe | awk '{gsub(/[^0-9]/,"",$0); $0=substr($0,1,4); if($0=="") $0="1000"; print}' | sort | uniq \
| while read a;
do
echo "WHEN (NEW.date_time >= '$a-01-01'::date AND NEW.date_time <= '$a-12-31'::date) THEN INSERT INTO clean.ufo_$a VALUES (NEW.*);"
done >> create_ufo_partition_trigger.sql

echo "ELSE INSERT INTO clean.ufo_overflow VALUES (NEW.*);" >> create_ufo_partition_trigger.sql

echo "END CASE;
	RETURN NULL;
END; \$f\$ LANGUAGE plpgsql;" >> create_ufo_partition_trigger.sql

echo "CREATE TRIGGER ufo_insert BEFORE INSERT ON clean.ufo
FOR EACH ROW EXECUTE PROCEDURE ufo_insert();" >> create_ufo_partition_trigger.sql

psql -d ufo -f create_ufo_partition_trigger.sql

-- Función para castear fechas
CREATE OR REPLACE FUNCTION is_valid_timestamp(text) RETURNS boolean LANGUAGE plpgsql immutable as $$
BEGIN
  RETURN CASE WHEN $1::timestamp IS NULL THEN false ELSE true end;
EXCEPTION WHEN others THEN
  RETURN false;
END;$$;

-- Limpiamos y guardamos en CLEAN
INSERT INTO clean.ufo (
	origin,
	id,
	date_time,
	year,
	month,
	day,
	weekday,
	city,
	state,
	shape,
	duration,
	number,
	units,
	seconds,
	summary,
	posted,
	description_url,
	long_description
)
(
	SELECT
		origin,
		id,
		date_time2 as date_time,
		extract(year from date_time2::date)::smallint as year, 
		extract(month from date_time2::date)::smallint as month,
		extract(day from date_time2::date)::smallint as day,
		extract(dow from date_time2::date)::smallint as weekday, -- 0 is Sunday
		city,
		state2 as state,
		shape,
		duration,
		number,
		units,
		CASE
			WHEN units = 'day' then t.number*3600*24
			WHEN units = 'hour' then t.number*3600
			WHEN units = 'min' then t.number*60
			WHEN units = 'sec' then t.number*1
		END as seconds,
		summary,
		posted2 as posted,
		description_url,
		long_description
	FROM (SELECT
		*,
		CASE
			WHEN is_valid_timestamp(date_time) THEN date_time::timestamp
			ELSE NULL
		END as date_time2,
		CASE
			WHEN is_valid_timestamp(posted) THEN posted::timestamp
			ELSE NULL
		END as posted2,
		CASE
			WHEN state = '' and city ~ '(.+)' THEN regexp_replace(city, '.+\((.+)\)', '\1')
			ELSE state
		END as state2,
		CASE
			WHEN number_char = NULL THEN -1.0
			WHEN duration ~ '-' THEN (split_part(number_char, '-', 1)::float +
				split_part(number_char, '-', 2)::float)::float / 2.0
			ELSE number_char::float
		END as number,
		CASE
			WHEN duration ~ 'day' then 'day'
			WHEN duration ~ 'hour' then 'hour'
			WHEN duration ~ 'min' then 'min'
			WHEN duration ~ 'sec' then 'sec'
		END as units
		FROM (SELECT *,
			CASE
				WHEN regexp_replace(duration, '[^\-\.0-9]', '', 'g') ~ '(^[0-9]+(\.[0-9]+)?$)|(^[0-9]+(\.[0-9]+)?-[0-9]+(\.[0-9]+)?$)'
					THEN regexp_replace(duration, '[^\.\-0-9]', '', 'g')
				ELSE NULL
			END as number_char
			FROM dirty.raw_input) d
		WHERE duration ~ 'day|hour|min|sec' and duration ~ '[0-9]') t
);

-- INDICE ESPACIO TEMPORAL
CREATE INDEX space_time_ufo_idx ON ufo (
	state, year, month, day, weekday
);






















