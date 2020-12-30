# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :alb_monitor, ex_aws: ExAws, http: HTTPoison

import_config "#{Mix.env()}.exs"
