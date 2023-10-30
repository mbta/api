# API Load Testing

This directory contains configuration for load testing using [Locust](https://locust.io/).

## Setup

1. Install the required `asdf` plugins for load testing:
   ```bash
   # install python and poetry plugins
   asdf plugin-add python
   asdf plugin-add poetry
   # install dependencies
   asdf install
   ```
1. Install Locust using Poetry:
   ```bash
   poetry install
   ```

## Running Locust

The Locust configuration requires an API key to be set in the environment using the `LOCUST_API_KEY` environment variable. The simplest way to run Locust is via the following command:

```bash
LOCUST_API_KEY="myapikey" poetry run locust --host="https://my-api-env.example.com"
```

Once Locust is running you can set up a test via your web browser at [http://localhost:8089](http://localhost:8089/).

A full list of Locust configuration options can be found in the [Locust documentation](https://docs.locust.io/en/stable/configuration.html).

## Caveats

The "tasks" that Locust runs are based on the 25 most frequently run&mdash;and most time-intensive to handle&mdash;queries on the production API. As such, this configuration is not meant to simulate regular load on the production API application, but is instead designed to generate a relatively high amount of load on in order to test the application's responsiveness and trigger auto scaling events. Whereas the production application can normally handle many hundreds of queries per second, only a few queries from Locust (around 5 per second per application instance) are required to generate a high load on the application.
