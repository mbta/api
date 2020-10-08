[![Build Status](https://semaphoreci.com/api/v1/mbta/api/branches/master/shields_badge.svg)](https://semaphoreci.com/mbta/api) [![codecov](https://codecov.io/gh/mbta/api/branch/master/graph/badge.svg?token=Ubzk57i0ia)](https://codecov.io/gh/mbta/api)


# V3 API

To start your Phoenix app:

  1. Install required **Erlang** and **Elixir** versions:
     1. Install [**asdf**](https://github.com/asdf-vm/asdf) package manager
     2. Run `asdf plugin-add erlang` to add Erlang plugin
     3. Run `asdf plugin-add elixir` to add Elixir plugin
     4. Run `asdf install` to install plugin versions speicifed in `.tool-versions` file
  2. Install dependencies with `mix deps.get`
  3. Setup `apps/api_accounts` following directions in `apps/api_accounts/README.md` (on [GitHub](apps/api_accounts/README.md#setting-up-dynamodb-local) or [ExDoc](api_accounts-readme.html#setting-up-dynamodb-local))
  4. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Environment Variables

In addition to the Elixir config files, the V3 API allows runtime configuration through a collection of environment variables.

| Environment Variable | Default | Description |
| - | - | - |
| `HTTP_ACCEPTS` | `json json-api event-stream` | Space-separated Phoenix types the API will accept. |
| `LOG_LEVEL` | `info` | Log level to use. Can be changed to `debug`. |
| `PORT` | `4000` | The HTTP port the server will listen on. |
| `HOST` | undefined | The public-facing hostname for the server, used to generate URLs. |
| `MBTA_GTFS_URL` | `https://cdn.mbta.com/MBTA_GTFS.zip` | URL for the GTFS .zip file. |
| `ALERTS_URL` | `https://cdn.mbta.com/realtime/Alerts_enhanced.json` | URL for the Alerts. Can be either a JSON or Protobuf file.
| `MBTA_TRIP_SOURCE` | `https://cdn.mbta.com/realtime/TripUpdates_enhanced.json` | URL for the TripUpdates. Can be either a JSON or Protobuf file. |
| `MBTA_VEHICLE_SOURCE ` | `https://cdn.mbta.com/realtime/VehiclePositions_enhanced.json` | URL for the VehiclePositions. Can be either a JSON or Protobuf file. |
| `IBM_PARKING_SOURCE` | undefined | URL for parking information. |
| `FETCH_FILETAP_S3_BUCKET` | undefined | S3 bucket to which we write files we fetched. |

## Documentation

### Swagger

[Swagger](https://swagger.io/docs/) documentation for the Api is generated automatically.

1. `mix phoenix.server`
2. `open http://localhost:4000/docs/swagger`

## Want to contribute?

Thank you for wanting to contribute! We use the built in `mix format` for code formatting, and `ExUnit` for testing.

```sh
# Format all code
$ mix format

# Run all unit tests
$ mix test

# Run the integration tests
$ mix test --exclude test --include integration
```

## Learn more

  * Docs: https://www.mbta.com/developers/v3-api
  * Mailing list: https://groups.google.com/forum/#!forum/massdotdevelopers

## About us

The MBTA Customer Technology team is working to transform how people get around the Boston area. We’re a small but mighty team of designers, engineers and content specialists charged with bringing novel ideas, modern standards and a user-centered approach to technology on the T. As the MBTA works to reinvent itself, we have a rare opportunity to shape the future of transportation for Boston and communities all around Eastern Massachusetts, as well as blaze a trail for other transit agencies around the country.

We’re always looking for people to join the team who are passionate about improving the daily transportation experience for our 400 million annual riders. Does this sound like you? Check our our open positions at https://jobs.lever.co/mbta/.
