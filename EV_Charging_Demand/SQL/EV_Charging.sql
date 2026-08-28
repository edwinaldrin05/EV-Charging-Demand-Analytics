--creating database--
CREATE DATABASE EV_CHARGING_DB;
USE DATABASE EV_CHARGING_DB;

--creating schema--
CREATE SCHEMA EV_DATA;
USE SCHEMA EV_DATA;
SELECT CURRENT_DATABASE(), CURRENT_SCHEMA();

--creating the stage--
CREATE OR REPLACE STAGE EV_CHARGING_STAGE;

-- then upload the csv file into the stage--
LIST @EV_CHARGING_STAGE;

-- creating the raw table--
CREATE OR REPLACE TABLE EV_CHARGING_RAW (
    timestamp TIMESTAMP_NTZ,
    vehicle_id VARCHAR,
    vehicle_type VARCHAR,
    battery_capacity_kWh NUMBER,
    station_id VARCHAR,
    location_type VARCHAR,
    traffic_density VARCHAR,
    weather_condition VARCHAR,
    assigned_charger_id VARCHAR,
    charging_power_kW NUMBER,
    arrival_time TIMESTAMP_NTZ,
    charging_start_time TIMESTAMP_NTZ,
    charging_end_time TIMESTAMP_NTZ,
    waiting_time NUMBER,
    initial_soc FLOAT,
    final_soc FLOAT,
    energy_consumed_kWh FLOAT,
    charging_duration FLOAT,
    queue_length NUMBER,
    station_load FLOAT,
    electricity_price FLOAT,
    renewable_energy_ratio FLOAT,
    charging_demand FLOAT,
    charging_priority VARCHAR,
    optimization_reward FLOAT,
    day_of_week VARCHAR,
    time_slot VARCHAR
);
DESC TABLE EV_CHARGING_RAW;
LIST @EV_CHARGING_STAGE;
-- then load the csv file into the table--

SELECT COUNT(*)
FROM EV_CHARGING_RAW;
SELECT *
FROM EV_CHARGING_RAW
LIMIT 10;

--- 1. creating dimension table (DimDate)---
CREATE OR REPLACE TABLE DimDate(
date_key DATE PRIMARY KEY,
day_of_week VARCHAR,
time_slot VARCHAR
);
-- inserting the values to DimDate---
INSERT INTO DimDate (
    date_key,
    day_of_week,
    time_slot
)
SELECT DISTINCT
    TO_DATE(timestamp) AS date_key,
    day_of_week,
    time_slot
FROM EV_CHARGING_RAW;

SELECT *
FROM DimDate
ORDER BY date_key;
SELECT COUNT(*)
FROM DimDate;

-- 2. creating the dimension table (DimVehicle)---
CREATE OR REPLACE TABLE DimVehicle (
    vehicle_key NUMBER AUTOINCREMENT PRIMARY KEY,
    vehicle_id VARCHAR,
    vehicle_type VARCHAR,
    battery_capacity_kWh NUMBER
);

-- inserting the date from the ev_charging_raw to DimVehicle---
INSERT INTO DimVehicle (
    vehicle_id,
    vehicle_type,
    battery_capacity_kWh
)
SELECT DISTINCT
    vehicle_id,
    vehicle_type,
    battery_capacity_kWh
FROM EV_CHARGING_RAW;

SELECT *
FROM DimVehicle
ORDER BY vehicle_key;
SELECT COUNT(*)
FROM DimVehicle;


--- 3. creating the dimension table (DimStation)---
CREATE OR REPLACE TABLE DimStation (
    station_key NUMBER AUTOINCREMENT PRIMARY KEY,
    station_id VARCHAR
);

--- inserting the data from the evcharging to dimstation---
INSERT INTO DimStation (
    station_id
)
SELECT DISTINCT
    station_id
FROM EV_CHARGING_RAW;

SELECT *
FROM DimStation
ORDER BY station_key;
SELECT COUNT(*)
FROM DimStation;

---4. creating the dimension table (DimLocation)---
CREATE OR REPLACE TABLE DimLocation (
    location_key NUMBER AUTOINCREMENT PRIMARY KEY,
    location_type VARCHAR,
    traffic_density VARCHAR,
    weather_condition VARCHAR
);

--inserting the data from the evcharging to the dimlocation---
INSERT INTO DimLocation (
    location_type,
    traffic_density,
    weather_condition
)
SELECT DISTINCT
    location_type,
    traffic_density,
    weather_condition
FROM EV_CHARGING_RAW;
SELECT *
FROM DimLocation
ORDER BY location_key;
SELECT COUNT(*)
FROM DimLocation;

-- creating the dimension table (dimcharger)---
CREATE OR REPLACE TABLE DimCharger (
    charger_key NUMBER AUTOINCREMENT PRIMARY KEY,
    assigned_charger_id VARCHAR,
    charging_power_kW NUMBER
);

--inserting the data from the evcharging to the dimcharger---
INSERT INTO DimCharger (
    assigned_charger_id,
    charging_power_kW
)
SELECT DISTINCT
    assigned_charger_id,
    charging_power_kW
FROM EV_CHARGING_RAW;
SELECT *
FROM DimCharger
ORDER BY charger_key;
SELECT COUNT(*)
FROM DimCharger;

--now we creating the central facat table (FastCharging)---
CREATE OR REPLACE TABLE FactCharging (
    charging_key NUMBER AUTOINCREMENT PRIMARY KEY,

    date_key DATE,
    vehicle_key NUMBER,
    station_key NUMBER,
    location_key NUMBER,
    charger_key NUMBER,

    arrival_time TIMESTAMP_NTZ,
    charging_start_time TIMESTAMP_NTZ,
    charging_end_time TIMESTAMP_NTZ,

    waiting_time NUMBER,
    initial_soc FLOAT,
    final_soc FLOAT,
    energy_consumed_kWh FLOAT,
    charging_duration FLOAT,
    queue_length NUMBER,
    station_load FLOAT,
    electricity_price FLOAT,
    renewable_energy_ratio FLOAT,
    charging_demand FLOAT,
    charging_priority VARCHAR,
    optimization_reward FLOAT
);
DESC TABLE FactCharging;
SELECT COUNT(*) FROM DimDate;
SELECT COUNT(*) FROM DimVehicle;
SELECT COUNT(*) FROM DimStation;
SELECT COUNT(*) FROM DimLocation;
SELECT COUNT(*) FROM DimCharger;

-- inserting the data for the fastcharging table from the evcharginraw table---
INSERT INTO FactCharging (
    date_key,
    vehicle_key,
    station_key,
    location_key,
    charger_key,
    arrival_time,
    charging_start_time,
    charging_end_time,
    waiting_time,
    initial_soc,
    final_soc,
    energy_consumed_kWh,
    charging_duration,
    queue_length,
    station_load,
    electricity_price,
    renewable_energy_ratio,
    charging_demand,
    charging_priority,
    optimization_reward
)
SELECT
    TO_DATE(r.timestamp) AS date_key,

    v.vehicle_key,

    s.station_key,

    l.location_key,

    c.charger_key,

    r.arrival_time,
    r.charging_start_time,
    r.charging_end_time,

    r.waiting_time,
    r.initial_soc,
    r.final_soc,
    r.energy_consumed_kWh,
    r.charging_duration,
    r.queue_length,
    r.station_load,
    r.electricity_price,
    r.renewable_energy_ratio,
    r.charging_demand,
    r.charging_priority,
    r.optimization_reward

FROM EV_CHARGING_RAW r

JOIN DimVehicle v
    ON r.vehicle_id = v.vehicle_id
    AND r.vehicle_type = v.vehicle_type
    AND r.battery_capacity_kWh = v.battery_capacity_kWh

JOIN DimStation s
    ON r.station_id = s.station_id

JOIN DimLocation l
    ON r.location_type = l.location_type
    AND r.traffic_density = l.traffic_density
    AND r.weather_condition = l.weather_condition

JOIN DimCharger c
    ON r.assigned_charger_id = c.assigned_charger_id
    AND r.charging_power_kW = c.charging_power_kW;
    SELECT COUNT(*)
FROM FactCharging;
SELECT *
FROM FactCharging
LIMIT 10;

SELECT
    COUNT(*) AS raw_rows
FROM EV_CHARGING_RAW;
SELECT
    COUNT(*) AS fact_rows
FROM FactCharging;

SELECT
    f.charging_key,
    f.date_key,
    v.vehicle_id,
    v.vehicle_type,
    v.battery_capacity_kWh,
    f.energy_consumed_kWh
FROM FactCharging f
JOIN DimVehicle v
    ON f.vehicle_key = v.vehicle_key
LIMIT 10;

SELECT
    f.charging_key,
    s.station_id,
    f.energy_consumed_kWh,
    f.station_load
FROM FactCharging f
JOIN DimStation s
    ON f.station_key = s.station_key
LIMIT 10;

SELECT
    f.charging_key,
    l.location_type,
    l.traffic_density,
    l.weather_condition,
    f.charging_demand
FROM FactCharging f
JOIN DimLocation l
    ON f.location_key = l.location_key
LIMIT 10;

SELECT
    f.charging_key,
    c.assigned_charger_id,
    c.charging_power_kW,
    f.energy_consumed_kWh,
    f.charging_duration
FROM FactCharging f
JOIN DimCharger c
    ON f.charger_key = c.charger_key
LIMIT 10;

SELECT
    f.charging_key,

    d.date_key,
    d.day_of_week,
    d.time_slot,

    v.vehicle_id,
    v.vehicle_type,
    v.battery_capacity_kWh,

    s.station_id,

    l.location_type,
    l.traffic_density,
    l.weather_condition,

    c.assigned_charger_id,
    c.charging_power_kW,

    f.arrival_time,
    f.charging_start_time,
    f.charging_end_time,
    f.waiting_time,
    f.initial_soc,
    f.final_soc,
    f.energy_consumed_kWh,
    f.charging_duration,
    f.queue_length,
    f.station_load,
    f.electricity_price,
    f.renewable_energy_ratio,
    f.charging_demand,
    f.charging_priority,
    f.optimization_reward

FROM FactCharging f

JOIN DimDate d
    ON f.date_key = d.date_key

JOIN DimVehicle v
    ON f.vehicle_key = v.vehicle_key

JOIN DimStation s
    ON f.station_key = s.station_key

JOIN DimLocation l
    ON f.location_key = l.location_key

JOIN DimCharger c
    ON f.charger_key = c.charger_key

LIMIT 10;

SELECT
    CURRENT_ACCOUNT() AS ACCOUNT,
    CURRENT_USER() AS USER_NAME,
    CURRENT_WAREHOUSE() AS WAREHOUSE,
    CURRENT_DATABASE() AS DATABASE_NAME,
    CURRENT_SCHEMA() AS SCHEMA_NAME,
    CURRENT_ROLE() AS ROLE_NAME;