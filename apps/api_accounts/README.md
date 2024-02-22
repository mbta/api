# ApiAccounts

Manages API accounts and API keys

## Defining a Schema

Look at `ApiAccounts.Table` for full details on how create a schema for a table.

```
defmodule User do
  use ApiAccounts.Table

  table "users" do
    field :email, :string, primary_key: true
    field :name, :string
    field :active, :boolean, default: true
    schema_version 1
  end
end
```

## Setting Up DynamoDB Local

Make sure you have Docker installed, and then run

```shell
docker compose up
```

Once DynamoDB is running, you can create a new admin user:

* Run the server in interactive shell:
  ```
  iex -S mix phx.server
  ```
* In the shell,
  * create `User` table:
    ```
    ApiAccounts.Dynamo.create_table(ApiAccounts.User)
    ```
  * create `Key` table:
    ```
    ApiAccounts.Dynamo.create_table(ApiAccounts.Key)
    ```
  * create a new user:
    ```
    ApiAccounts.create_user(%{email: "test@example.com", password: "test", role: "administrator"})
    ```

## Installation

To use in another OTP app in this umbrella project

  1. Add `api_accounts` to your list of dependencies in `mix.exs`

        def deps do
          [{:api_accounts, in_umbrella: true}]
        end

  2. Ensure `api_accounts` is started before your application:

        def application do
          [applications: [:api_accounts]]
        end
