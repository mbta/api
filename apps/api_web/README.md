# Api

**TODO: Add description**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `api` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:api, "~> 0.1.0"}]
    end
    ```

  2. Ensure `api` is started before your application:

    ```elixir
    def application do
      [applications: [:api]]
    end
    ```


## Swagger and Tests

The Swagger API documentation is used to validate incoming requests to all
requests that use the :api pipeline (see
`apps/api_web/lib/api_web/router.ex`).
