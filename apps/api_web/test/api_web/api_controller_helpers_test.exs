defmodule ApiWeb.ApiControllerHelpersTest do
  use ApiWeb.ConnCase

  @base_url ApiWeb.Endpoint.url()

  describe "pagination_links/2" do
    test "generates the proper page links" do
      query_params = %{"page" => %{"limit" => "2", "offset" => "4"}}

      offsets = %State.Pagination.Offsets{
        next: 6,
        prev: 2,
        first: 0,
        last: 8
      }

      conn = %Plug.Conn{
        query_params: query_params,
        request_path: "/endpoint",
        private: %{phoenix_endpoint: ApiWeb.Endpoint}
      }

      page_links = ApiWeb.ApiControllerHelpers.pagination_links(conn, offsets)

      assert page_links[:first] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=0"
      assert page_links[:last] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=8"
      assert page_links[:prev] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=2"
      assert page_links[:next] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=6"
    end

    test "excludes nil offsets" do
      query_params = %{"page" => %{"limit" => "2", "offset" => "4"}}

      offsets = %State.Pagination.Offsets{
        next: nil,
        prev: 2,
        first: 0,
        last: 4
      }

      conn = %Plug.Conn{
        query_params: query_params,
        request_path: "/endpoint",
        private: %{phoenix_endpoint: ApiWeb.Endpoint}
      }

      page_links = ApiWeb.ApiControllerHelpers.pagination_links(conn, offsets)

      assert page_links[:first] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=0"
      assert page_links[:last] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=4"
      assert page_links[:next] == nil
      assert page_links[:prev] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=2"
    end

    test "accounts for when no offset is provided in query params" do
      query_params = %{"page" => %{"limit" => "2"}}

      offsets = %State.Pagination.Offsets{
        next: 2,
        prev: nil,
        first: 0,
        last: 4
      }

      conn = %Plug.Conn{
        query_params: query_params,
        request_path: "/endpoint",
        private: %{phoenix_endpoint: ApiWeb.Endpoint}
      }

      page_links = ApiWeb.ApiControllerHelpers.pagination_links(conn, offsets)

      assert page_links[:first] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=0"
      assert page_links[:last] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=4"
      assert page_links[:prev] == nil
      assert page_links[:next] == "#{@base_url}/endpoint?page[limit]=2&page[offset]=2"
    end
  end

  describe "filter_valid_field_params/1" do
    test "keeps valid fields" do
      params = %{"shape" => "priority,relationship,name"}

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == %{
               "shape" => [:priority, :name]
             }
    end

    test "works with types with multiple words" do
      params = %{"route_pattern" => "name,typicality,canonical"}

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == %{
               "route_pattern" => [:name, :typicality, :canonical]
             }
    end

    test "rejects invalid types" do
      params = %{
        "bad_type" => "name",
        "another_bad_type" => "attribute",
        "shape" => "polyline,relationship,name",
        "route" => "description,long_name,type"
      }

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) ==
               %{"shape" => [:polyline, :name], "route" => [:description, :long_name, :type]}
    end

    test "invalid attributes are dropped" do
      params = %{"shape" => "relationship"}

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == %{
               "shape" => []
             }
    end

    test "empty attributes are mapped to the empty list" do
      params = %{"stop" => ""}

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == %{
               "stop" => []
             }
    end

    test "omitted attributes are mapped to the empty list" do
      params = %{"stop" => nil}

      assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == %{
               "stop" => []
             }
    end

    test "non-map arguments are mapped to nil" do
      for params <- [[], ["one"], "", "invalid", nil] do
        assert ApiWeb.ApiControllerHelpers.filter_valid_field_params(%Plug.Conn{}, params) == nil
      end
    end
  end

  describe "opts_for_params/2" do
    test "includes valid types/attributes for field key" do
      params = %{
        "fields" => %{
          "bad_type" => "name",
          "shape" => "priority,relationship,name"
        }
      }

      result = ApiWeb.ApiControllerHelpers.opts_for_params(%Plug.Conn{}, params)
      assert result[:fields] == %{"shape" => [:priority, :name]}
    end
  end

  describe "split_include/2" do
    test "doesn't error when includes is a map" do
      conn =
        %Plug.Conn{params: %{"include" => %{"bad" => ""}}}
        |> ApiWeb.ApiControllerHelpers.split_include([])

      assert conn.assigns[:split_include] == []
    end
  end

  describe "server_sent_event streaming" do
    test "returns 406 for a 'show' endpoint", %{conn: conn} do
      response =
        conn
        |> put_req_header("accept", "text/event-stream")
        |> get(vehicle_path(conn, :show, 1))

      assert %{
               "errors" => [
                 %{
                   "status" => "406",
                   "code" => "not_acceptable",
                   "detail" => "Streaming not supported" <> _
                 }
               ]
             } = json_response(response, 406)
    end
  end
end
