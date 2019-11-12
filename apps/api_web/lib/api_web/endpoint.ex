defmodule ApiWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :api_web

  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.Static, at: "/", from: :api_web, gzip: false, only: ~w(js css images favicon.ico))

  plug(Plug.RequestId)
  plug(Logster.Plugs.Logger)

  plug(
    Plug.Parsers,
    parsers: [:urlencoded],
    pass: ["application/json", "application/vnd.api+json", "application/x-www-form-urlencoded"]
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(ApiWeb.Plugs.Deadline)
  # CORS needs to be before the router, and Authenticate needs to be before CORS
  plug(ApiWeb.Plugs.Authenticate)
  plug(ApiWeb.Plugs.CORS)
  plug(ApiWeb.Plugs.RequestTrack, name: ApiWeb.RequestTrack)
  plug(ApiWeb.Router)
end
