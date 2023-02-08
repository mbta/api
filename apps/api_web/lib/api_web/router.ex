defmodule ApiWeb.Router do
  use ApiWeb.Web, :router

  defdelegate set_content_type(conn, opts), to: JaSerializer.ContentTypeNegotiation

  @rate_limit_headers """
  The HTTP headers returned in any API response show your rate limit status:
  | Header | Description |
  | ------ | ----------- |
  | `x-ratelimit-limit` | The maximum number of requests you're allowed to make per time window. |
  | `x-ratelimit-remaining` | The number of requests remaining in the current time window. |
  | `x-ratelimit-reset` | The time at which the current rate limit time window ends in UTC epoch seconds. |
  """

  pipeline :secure do
    if force_ssl = Application.compile_env(:site, :secure_pipeline)[:force_ssl] do
      plug(Plug.SSL, force_ssl)
    end
  end

  pipeline :browser do
    plug(
      Plug.Session,
      store: :cookie,
      key: "_api_key",
      signing_salt: {Application, :get_env, [:api_web, :signing_salt]}
    )

    @content_security_policy Enum.join(
                               [
                                 "default-src 'none'",
                                 "img-src 'self' cdn.mbta.com",
                                 "style-src 'self' 'unsafe-inline' maxcdn.bootstrapcdn.com fonts.googleapis.com",
                                 "script-src 'self' maxcdn.bootstrapcdn.com code.jquery.com",
                                 "font-src fonts.gstatic.com maxcdn.bootstrapcdn.com"
                               ],
                               "; "
                             )
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers, %{"content-security-policy" => @content_security_policy})
    plug(ApiWeb.Plugs.FetchUser)
    plug(ApiWeb.Plugs.CheckForShutdown)
  end

  pipeline :admin_view do
    plug(:put_layout, {ApiWeb.Admin.LayoutView, :app})
  end

  pipeline :admin do
    plug(ApiWeb.Plugs.RequireAdmin)
  end

  pipeline :portal_view do
    plug(:put_layout, {ApiWeb.ClientPortal.LayoutView, :app})
  end

  pipeline :portal do
    plug(ApiWeb.Plugs.RequireUser)
  end

  pipeline :api do
    plug(:accepts_runtime)
    plug(:set_content_type)
    plug(ApiWeb.Plugs.Version)
    plug(:authenticated_accepts, ApiWeb.config(:api_pipeline, :authenticated_accepts))
    plug(ApiWeb.Plugs.CheckForShutdown)
  end

  scope "/", ApiWeb do
    pipe_through(:api)

    get("/_health", HealthController, :index)
  end

  scope "/", ApiWeb do
    pipe_through([:secure, :api])

    get("/status", StatusController, :index)
    resources("/stops", StopController, only: [:index, :show])
    resources("/routes", RouteController, only: [:index, :show])
    resources("/route_patterns", RoutePatternController, only: [:index, :show])
    resources("/route-patterns", RoutePatternController, only: [:index, :show])
    resources("/lines", LineController, only: [:index, :show])
    resources("/shapes", ShapeController, only: [:index, :show])
    get("/predictions", PredictionController, :index)
    get("/schedules", ScheduleController, :index)
    resources("/vehicles", VehicleController, only: [:index, :show])
    resources("/trips", TripController, only: [:index, :show])
    resources("/alerts", AlertController, only: [:index, :show])
    resources("/facilities", FacilityController, only: [:index, :show])
    resources("/live_facilities", LiveFacilityController, only: [:index, :show])
    resources("/live-facilities", LiveFacilityController, only: [:index, :show])
    resources("/services", ServiceController, only: [:index, :show])
  end

  scope "/docs/swagger" do
    pipe_through(:secure)
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :api_web, swagger_file: "swagger.json")
  end

  # Admin Portal routes

  scope "/admin", ApiWeb.Admin, as: :admin do
    pipe_through([:secure, :browser, :admin_view])

    get("/login", SessionController, :new)
    post("/login", SessionController, :create)
    delete("/logout", SessionController, :delete)
  end

  scope "/admin/users", ApiWeb.Admin.Accounts, as: :admin do
    pipe_through([:secure, :browser, :admin_view, :admin])
    resources("/", UserController)
  end

  scope "/admin/users/:user_id/keys", ApiWeb.Admin.Accounts, as: :admin do
    pipe_through([:secure, :browser, :admin_view, :admin])
    resources("/", KeyController, only: [:create, :edit, :update, :delete])
    put("/:id/clone", KeyController, :clone)
    put("/:id/approve", KeyController, :approve)
  end

  scope "/admin/keys", ApiWeb.Admin.Accounts, as: :admin do
    pipe_through([:secure, :browser, :admin_view, :admin])

    get("/", KeyController, :index)
    get("/:key", KeyController, :redirect_to_user_by_id)
    post("/search", KeyController, :find_user_by_key)
  end

  # Client Portal routes

  scope "/", ApiWeb.ClientPortal do
    pipe_through([:secure, :browser, :portal_view])

    get("/", PortalController, :landing)

    get("/login", SessionController, :new)
    post("/login", SessionController, :create)

    get("/register", UserController, :new)
    post("/register", UserController, :create)

    get("/forgot-password", UserController, :forgot_password)
    post("/forgot-password", UserController, :forgot_password_submit)

    get("/reset-password", UserController, :reset_password)
    post("/reset-password", UserController, :reset_password_submit)
  end

  scope "/portal", ApiWeb.ClientPortal do
    pipe_through([:secure, :browser, :portal_view, :portal])

    get("/", PortalController, :index)
    resources("/keys", KeyController, only: [:create, :edit, :update])
    get("/keys/:id/request_increase", KeyController, :request_increase)
    post("/keys/:id/request_increase", KeyController, :do_request_increase)
    delete("/logout", SessionController, :delete)

    resources(
      "/account",
      UserController,
      only: [:show, :edit, :update],
      singleton: true
    )

    get("/account/edit-password", UserController, :edit_password)
  end

  if Mix.env() == :dev do
    scope "/sent_emails" do
      forward("/", Bamboo.SentEmailViewerPlug)
    end
  end

  def swagger_info do
    %{
      info: %{
        title: "MBTA",
        description:
          "MBTA service API. https://www.mbta.com Source code: https://github.com/mbta/api",
        termsOfService: "http://www.massdot.state.ma.us/DevelopersData.aspx",
        contact: %{
          name: "MBTA Developer",
          url: "https://groups.google.com/forum/#!forum/massdotdevelopers",
          email: "developer@mbta.com"
        },
        license: %{
          name: "MassDOT Developer's License Agreement",
          url:
            "http://www.massdot.state.ma.us/Portals/0/docs/developers/develop_license_agree.pdf"
        },
        version: "3.0"
      },
      definitions: %{
        NotFound: %{
          type: :object,
          description: "A JSON-API error document when a resource is not found",
          required: [:errors],
          properties: %{
            errors: %{
              type: :array,
              items: %{
                type: :object,
                description: "A JSON-API error when a resource is not found",
                properties: %{
                  code: %{
                    type: :string,
                    description: "An application-specific error code",
                    example: "not_found"
                  },
                  source: %{
                    type: :object,
                    description: "A JSON-API error source",
                    properties: %{
                      parameter: %{
                        type: :string,
                        description:
                          "The name of parameter that was used to lookup up the resource that was not found",
                        example: "id"
                      }
                    }
                  },
                  status: %{
                    type: :string,
                    description: "The HTTP status code applicable to the problem",
                    example: "404"
                  },
                  title: %{
                    type: :string,
                    description: "A short, human-readable summary of the problem",
                    example: "Resource Not Found"
                  }
                }
              },
              maxItems: 1,
              minItems: 1
            }
          }
        },
        BadRequest: %{
          type: :object,
          description: """
          A JSON-API error document when the server cannot or will not process \
          the request due to something that is perceived to be a client error.
          """,
          required: [:errors],
          properties: %{
            errors: %{
              type: :array,
              items: %{
                type: :object,
                description: "A JSON-API error when a bad request is received",
                properties: %{
                  code: %{
                    type: :string,
                    description: "An application-specific error code",
                    example: "bad_request"
                  },
                  source: %{
                    type: :object,
                    description: "A JSON-API error source",
                    properties: %{
                      parameter: %{
                        type: :string,
                        description: "The name of parameter that caused the error",
                        example: "sort"
                      }
                    }
                  },
                  status: %{
                    type: :string,
                    description: "The HTTP status code applicable to the problem",
                    example: "400"
                  },
                  detail: %{
                    type: :string,
                    description: "A short, human-readable summary of the problem",
                    example: "Invalid sort key"
                  }
                }
              },
              maxItems: 1,
              minItems: 1
            }
          }
        },
        Forbidden: %{
          type: :object,
          description: "A JSON-API error document when the API key is invalid",
          required: [:errors],
          properties: %{
            errors: %{
              type: :array,
              items: %{
                type: :object,
                description: "A JSON-API error when an invalid API key is received",
                properties: %{
                  code: %{
                    type: :string,
                    description: "An application-specific error code",
                    example: "forbidden"
                  },
                  status: %{
                    type: :string,
                    description: "The HTTP status code applicable to the problem",
                    example: "403"
                  }
                }
              },
              maxItems: 1,
              minItems: 1
            }
          }
        },
        TooManyRequests: %{
          type: :object,
          description: "A JSON-API error document when rate limited",
          required: [:errors],
          properties: %{
            errors: %{
              type: :array,
              items: %{
                type: :object,
                description: "A JSON-API error when rate limited",
                properties: %{
                  code: %{
                    type: :string,
                    description: "An application-specific error code",
                    example: "rate_limited"
                  },
                  status: %{
                    type: :string,
                    description: "The HTTP status code applicable to the problem",
                    example: "429"
                  },
                  detail: %{
                    type: :string,
                    description: "Human-readable summary of the problem",
                    example: "You have exceeded your allowed usage rate."
                  }
                }
              },
              maxItems: 1,
              minItems: 1
            }
          }
        },
        NotAcceptable: %{
          type: :object,
          description: "A JSON-API error document when a request uses an invalid 'accept' header",
          required: [:errors],
          properties: %{
            errors: %{
              type: :array,
              items: %{
                type: :object,
                description: "A JSON-API error when a request uses an invalid 'accept' header",
                properties: %{
                  code: %{
                    type: :string,
                    description: "An application-specific error code",
                    example: "not_acceptable"
                  },
                  status: %{
                    type: :string,
                    description: "The HTTP status code applicable to the problem",
                    example: "406"
                  },
                  detail: %{
                    type: :string,
                    description: "Human-readable summary of the problem",
                    example:
                      "Content-type text/event-stream is not supported for this kind of request."
                  }
                }
              },
              maxItems: 1,
              minItems: 1
            }
          }
        }
      },
      securityDefinitions: %{
        api_key_in_query: %{
          type: "apiKey",
          name: "api_key",
          in: "query",
          description: """
          ##### Query Parameter
          Without an api key in the query string or as a request header, requests will be tracked by IP address and have stricter rate limit. \
          [Register for a key](/register)

          #{@rate_limit_headers}
          """
        },
        api_key_in_header: %{
          type: "apiKey",
          name: "x-api-key",
          in: "header",
          description: """
          ##### Header
          Without an api key as a request header or in the query string, requests will be tracked by IP address and have stricter rate limit. \
          [Register for a key](/register)

          #{@rate_limit_headers}
          """
        }
      },
      security: [
        %{api_key_in_query: []},
        %{api_key_in_header: []}
      ]
    }
  end

  @doc """
  Like `accepts/2` but fetches the acceptable types at runtime instead of compile time.
  """
  def accepts_runtime(conn, []) do
    runtime_accepts = ApiWeb.config(:api_pipeline, :accepts)
    accepts(conn, runtime_accepts)
  end

  @doc """
  With an anonymous user, also require that the format is allowed for anonymous users.
  """
  def authenticated_accepts(%{assigns: %{api_user: %{type: :anon}}} = conn, [_ | _] = accepts) do
    if Phoenix.Controller.get_format(conn) in accepts do
      anon_accepts = ApiWeb.config(:api_pipeline, :accepts) -- accepts
      accepts(conn, anon_accepts)
    else
      conn
    end
  end

  def authenticated_accepts(conn, _) do
    conn
  end
end
