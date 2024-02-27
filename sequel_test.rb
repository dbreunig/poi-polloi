require "roda"
require "sqlite3"
require "json"

EARTH_RADIUS_IN_METERS = 6371000.0
RADIANS_TO_DEGREES = 180.0 / Math::PI

def bounding_box(latitude, longitude, meters)
  lat_diff = meters / EARTH_RADIUS_IN_METERS * RADIANS_TO_DEGREES
  long_diff = meters / (EARTH_RADIUS_IN_METERS * Math.cos(latitude * Math::PI / 180)) * RADIANS_TO_DEGREES

  min_lat = latitude - lat_diff
  min_long = longitude - long_diff
  max_lat = latitude + lat_diff
  max_long = longitude + long_diff

  [min_lat, min_long, max_lat, max_long]
end

def distance(loc1, loc2)
  rad_per_deg = Math::PI / 180  # PI / 180
  rkm = 6371          # Earth radius in kilometers
  rm = rkm * 1000    # Radius in meters

  dlat_rad = (loc2[0] - loc1[0]) * rad_per_deg # Delta, converted to rad
  dlon_rad = (loc2[1] - loc1[1]) * rad_per_deg

  lat1_rad = loc1.map { |i| i * rad_per_deg }.first
  lat2_rad = loc2.map { |i| i * rad_per_deg }.first

  a = Math.sin(dlat_rad / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad / 2)**2
  c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  rm * c # Delta in meters
end
RESULTS_PER_PAGE = 20

@db = SQLite3::Database.new("places.db")
@db.results_as_hash = true

example_coordinates = [37.76258607908846, -122.24423429364207]
bb = bounding_box(*example_coordinates, 100)

p bb

results = @db.execute("
  SELECT p.id, p.latitude, p.longitude, p.name, p.main_category, p.website,
    p.social, p.phone, p.address, p.locality, p.postcode, p.region, p.country
  FROM spatial_index AS si JOIN places AS p ON si.id = p.rowid
  WHERE si.minLat > ? AND si.minLong > ? AND si.maxLat < ? AND si.maxLong < ?
", bb)

results = results.sort_by { |p| distance(example_coordinates, [p["latitude"], p["longitude"]]) }

results.sort_by().each do |p|
  distance = distance(example_coordinates, [p["latitude"], p["longitude"]])
  puts "#{p["name"]} is #{distance.round(2)} meters away"
end
