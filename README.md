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
  4. Setup `apps/state_mediator` following directions in `apps/state_mediator/README.md` (on [GitHub](apps/state_mediator/README.md#installation) or [ExDoc](state_mediator-readme.html#installation))
  5. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

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
