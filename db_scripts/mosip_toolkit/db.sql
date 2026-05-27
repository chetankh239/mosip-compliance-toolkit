CREATE DATABASE :mosipdbname
	ENCODING = 'UTF8'
	LC_COLLATE = 'en_US.UTF-8'
	LC_CTYPE = 'en_US.UTF-8'
	TABLESPACE = pg_default
	OWNER = postgres
	TEMPLATE  = template0;
COMMENT ON DATABASE :mosipdbname IS 'Toolkit database to store the data for compliance testing';

\c :mosipdbname

DROP SCHEMA IF EXISTS toolkit CASCADE;
CREATE SCHEMA toolkit;
ALTER SCHEMA toolkit OWNER TO postgres;
ALTER DATABASE :mosipdbname SET search_path TO toolkit,pg_catalog,public;
