defmodule ApiWeb.Web do
  @moduledoc """
  A module that keeps using definitions for controllers,
  views and so on.

  This can be used in your application as:

      use ApiWeb.Web, :controller
      use ApiWeb.Web, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below.
  """

  def api_controller do
    quote location: :keep do
      use Phoenix.Controller,
        formats: [{:json, "View"}, {:"json-api", "View"}, {:"event-stream", "View"}],
        namespace: ApiWeb

      use ApiWeb.ApiControllerHelpers
      import ApiWeb.ControllerHelpers
      alias ApiWeb.Params
      use PhoenixSwagger
      import ApiWeb.SwaggerHelpers
    end
  end

  def controller do
    quote location: :keep do
      use Phoenix.Controller,
        formats: [html: "View", "json-api": "View"],
        layouts: [html: {ApiWeb.ClientPortal.LayoutView, :app}],
        namespace: ApiWeb

      import ApiWeb.Router.Helpers
    end
  end

  def api_view do
    quote do
      use JaSerializer
      use ApiWeb.ApiViewHelpers
      @dialyzer :no_match
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/api_web/templates",
        namespace: ApiWeb

      import Phoenix.Controller, only: [get_csrf_token: 0, view_module: 1]
      use PhoenixHTML4Compat
      import ApiWeb.Router.Helpers
      import ApiWeb.ErrorHelpers
      import ApiWeb.ViewHelpers
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Phoenix.Controller
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
