defmodule SwaggerHelpersTest do
  use ExUnit.Case, async: true

  alias PhoenixSwagger.Path.PathObject

  import ApiWeb.SwaggerHelpers

  describe "include_parameters/2" do
    test "adds provided include parameters" do
      include_param =
        %PathObject{}
        |> include_parameters(~w(stop route))
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == :include end)

      assert include_param
      assert include_param.description =~ "stop"
      assert include_param.description =~ "route"
    end
  end

  describe "filter_parameter/3" do
    test "route_type" do
      param =
        %PathObject{}
        |> filter_param(:route_type)
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[route_type]" end)

      assert param.type == :string
      assert param.enum == ["0", "1", "2", "3", "4"]
    end

    test "direction_id" do
      param =
        %PathObject{}
        |> filter_param(:direction_id)
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[direction_id]" end)

      assert param.type == :string
      assert param.enum == ["0", "1"]
    end

    test "position" do
      params =
        %PathObject{}
        |> filter_param(:position, description: "Filter stop by its location.")
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.filter(fn %{name: name} ->
          name in ["filter[latitude]", "filter[longitude]", "filter[radius]"]
        end)

      assert Enum.count(params) == 2
      assert Enum.map(params, &Map.get(&1, :type)) == [:string, :string]

      description =
        "Filter stop by its location. Latitude/Longitude must be" <>
          " both present or both absent."

      assert Enum.map(params, &Map.get(&1, :description)) == [description, description]
    end

    test "date" do
      param =
        %PathObject{}
        |> filter_param(:date, description: "Filter trip by date it is scheduled.")
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[date]" end)

      assert param.type == :string
      assert param.format == :date
      assert param.description =~ "Filter trip by date it is scheduled."
      assert param.description =~ "YYYY-MM-DD"
      assert param.description =~ "ISO8601"
    end

    test "time" do
      param =
        %PathObject{}
        |> filter_param(
          :time,
          description: "Filter trip to those running at a particular time."
        )
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[time]" end)

      assert param.type == :string
      assert param.format == :time
      assert param.description =~ "Filter trip to those running at a particular time."
      assert param.description =~ "The time format is HH:MM."
    end

    test "time takes alternate name" do
      param =
        %PathObject{}
        |> filter_param(
          :time,
          description: "Filter trip to those running at a particular time.",
          name: :min_time
        )
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[min_time]" end)

      assert param.type == :string
      assert param.format == :time
      assert param.description =~ "Filter trip to those running at a particular time."
      assert param.description =~ "The time format is HH:MM."
    end

    test "id" do
      param =
        %PathObject{}
        |> filter_param(:id, name: :route)
        |> Map.get(:operation)
        |> Map.get(:parameters)
        |> Enum.find(fn %{name: name} -> name == "filter[route]" end)

      assert param.type == :string
      assert param.description =~ "Filter by `/data/{index}/relationships/route/data/id`."

      assert param.description =~
               "Multiple IDs **MUST** be a comma-separated (U+002C COMMA, \",\") list."
    end
  end

  describe "path/2" do
    test "returns an index path" do
      assert "/alerts" == path(ApiWeb.AlertController, :index)
    end

    test "returns a show path with a formatted id placeholder" do
      assert "/alerts/{id}" == path(ApiWeb.AlertController, :show)
    end
  end

  describe "page/1" do
    test "returns a JSON API schema for a single reference without the meta property" do
      refute page(AlertResource)["properties"]["meta"]
    end
  end
end
