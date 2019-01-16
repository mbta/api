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

Download [DynamoDB local](http://docs.aws.amazon.com/amazondynamodb/latest/developerguide/DynamoDBLocal.html).

```
(mkdir -p bin/dynamodb && \
cd bin/dynamodb && \
curl -O https://s3-us-west-2.amazonaws.com/dynamodb-local/dynamodb_local_latest.tar.gz && \
tar -xzf dynamodb_local_latest.tar.gz && \
rm dynamodb_local_latest.tar.gz)
```

Run the JAR file to start the local DynamoDB server:

```
(export DYNAMODB_PATH=./bin/dynamodb && \
java -Djava.library.path=${DYNAMODB_PATH}/DynamoDBLocal_lib -jar ${DYNAMODB_PATH}/DynamoDBLocal.jar -sharedDb)
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
