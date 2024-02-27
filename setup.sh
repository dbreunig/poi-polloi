#!/bin/bash

# Create a folder called data
mkdir -p data

# Find the most recent parquet directory with the theme 'places'
recent_dir=$(aws s3 ls s3://overturemaps-us-west-2/release/ --recursive | grep "theme=places" | sort | tail -n 1 | awk -F '/' '{print $1"/"$2"/"$3"/"$4}')

# Extract the release date from the directory path
release_date=$(echo $recent_dir | awk -F '/' '{print $2}')

# Download the entire directory
echo "Downloading data from ${release_date}"
# aws s3 cp s3://overturemaps-us-west-2/release/$release_date/theme=places data/${release_date} --recursive

# Extract the data you want into a CSV file
echo "Extracting data from ${release_date}"
duckdb :memory: <<SQL
  INSTALL spatial;
  LOAD spatial;
  COPY (
    SELECT
      id,
      ST_GeomFromWKB(geometry) AS geometry,
      ST_X(ST_GeomFromWKB(geometry)) AS longitude,
      ST_Y(ST_GeomFromWKB(geometry)) AS latitude,
      names.primary,
      updateTime,
      categories.main as main_category,
      categories.alternate as alternate_categories,
      confidence,
      websites[1] as website,
      socials[1] as social,
      emails[1] as email,
      phones[1] as phone,
      brand.names.primary as brand,
      addresses[1].freeform as address,
      addresses[1].locality as locality,
      addresses[1].postcode as postcode,
      addresses[1].region as region,
      addresses[1].country as country,
    FROM
      parquet_scan('data/${release_date}/type=place/*.parquet')
  ) TO 'places.csv' (HEADER false);
SQL

# Setup the DB
echo "Setting up the DB"
rm -rf places.db
sqlite3 places.db <<SQL
CREATE TABLE temp_places (
  id TEXT,
  geometry TEXT,
  longitude REAL,
  latitude REAL,
  name TEXT,
  updateTime TEXT,
  main_category TEXT,
  alternate_categories TEXT,
  confidence REAL,
  website TEXT,
  social TEXT,
  email TEXT,
  phone TEXT,
  brand TEXT,
  address TEXT,
  locality TEXT,
  postcode TEXT,
  region TEXT,
  country TEXT
);
CREATE TABLE places (
  rowid INTEGER PRIMARY KEY AUTOINCREMENT,
  id TEXT,
  geometry TEXT,
  longitude REAL,
  latitude REAL,
  name TEXT,
  updateTime TEXT,
  main_category TEXT,
  alternate_categories TEXT,
  confidence REAL,
  website TEXT,
  social TEXT,
  email TEXT,
  phone TEXT,
  brand TEXT,
  address TEXT,
  locality TEXT,
  postcode TEXT,
  region TEXT,
  country TEXT
);
SQL

# Import the CSV into the DB
# We import the csv into a temp table first because we need
# an autoincrementing primary key for the spatial index.
echo "Importing the CSV into the DB"
sqlite3 places.db <<SQL
.mode csv
.import places.csv temp_places
INSERT INTO places (
  id,
  geometry,
  longitude,
  latitude,
  name,
  updateTime,
  main_category,
  alternate_categories,
  confidence,
  website,
  social,
  email,
  phone,
  brand,
  address,
  locality,
  postcode,
  region,
  country
) SELECT * FROM temp_places;
DROP TABLE temp_places;
VACUUM;
SQL

# Create an index for the id
echo "Creating an index for the id"
sqlite3 places.db <<SQL
  CREATE INDEX id_index ON places (id);
SQL

# Set up the spatial index
echo "Setting up the spatial index"
sqlite3 places.db <<SQL
CREATE VIRTUAL TABLE spatial_index USING rtree(
   id INTEGER PRIMARY KEY,
   minLat REAL,
   maxLat REAL,
   minLong REAL,
   maxLong REAL
);
INSERT INTO spatial_index (id, minLat, maxLat, minLong, maxLong)
SELECT rowid, latitude, latitude, longitude, longitude 
FROM places;
SQL

# Set up the FTS index
echo "Setting up the FTS index"
sqlite3 places.db <<SQL
CREATE VIRTUAL TABLE fts_index USING fts5(
  name,
  brand
);
INSERT INTO fts_index (name, brand)
SELECT name, brand FROM places;
SQL

# Create postcode and country indexes
echo "Creating postcode and country indexes"
sqlite3 places.db <<SQL
CREATE INDEX postcode_index ON places (postcode);
CREATE INDEX country_index ON places (country);
SQL


# Print the number of rows in the DB
echo "Number of rows in the DB:"
sqlite3 places.db <<SQL
SELECT COUNT(*) FROM places;
SQL

# Clean up
rm -Rf data
rm places.csv
