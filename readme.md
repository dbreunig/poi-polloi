To run the `setup.sh` file you need the `awscli` and `duckdb` installed. You can install them using the following commands:

```bash
pip install awscli
pip install duckdb
```

To run the API service, you need to have Ruby installed and have the `roda` and `sequel` gems installed. You can install them using the following commands:

```bash
gem install roda
gem install sequel
```

## Running the API service

First, run the `setup.sh` file to download the data and set up the database.

```bash
./setup.sh
```

The app is a simple Roda application, which can be run with `rackup`. The API service will be available at `http://localhost:9292`.

Currently, the API service has the following endpoints:

- `GET /poi?id=[ID]` - Returns data for a POI with the given ID.
- `GET /neaby?lat=[LAT]&lon=[LON]&page=[PAGE]` - Returns data for POIs nearest the provided coordinates. The `page` parameter is optional and defaults to 1.
- `GET /search?query=[QUERY]&country=[COUNTRY]&page=[PAGE]` - Returns data for POIs that match the provided query. The `country` parameter is the two-letter country code (e.g. "US"). The `page` parameter is optional and defaults to 1.