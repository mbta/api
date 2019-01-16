defmodule Parse.VariantTest do
  use ExUnit.Case, async: true
  import Parse.Variant
  alias Parse.Variant

  @header "shape_id,route_id,via_variant,trp_direction,trip_headsign"

  describe "parse/1" do
    test "can parse a basic row" do
      blob = """
      #{@header}
      010058,01,_,Inbound,Dudley
      """

      assert parse(blob) == [
               %Variant{id: "010058", name: "Dudley", primary?: true, replaced?: false}
             ]
    end

    test "marks the _ variant as primary even if isn't first" do
      blob = """
      #{@header}
      380041,38,1,Outbound,Wren St. via Forest Hills
      380043,38,_,Outbound,Wren St. via Centre St.
      """

      parsed = parse(blob)

      assert [
               %Variant{id: "380043", primary?: true},
               %Variant{id: "380041", primary?: false}
             ] = parsed
    end

    test "marks the _ variant as primary if they have the `ou` suffix" do
      blob = """
      #{@header}
      2010023,201,_ou,Outbound,Adams & Gallivan via Neponset Ave.
      2010039,201,8ou,Outbound,Keystone Apts. via Neponset Ave.
      """

      parsed = parse(blob)

      assert [
               %Variant{id: "2010023", primary?: true},
               %Variant{id: "2010039", primary?: false}
             ] = parsed
    end

    test "marks variants as replaced? if they're in trip_route_direction" do
      blob = """
      #{@header}
      1920018,192,_,Inbound,Haymarket via Forest Hills
      """

      trip_route_direction = """
      old_route_id_short,via_variant,old_direction,new_direction,replace_route_id,new_route_id_short
      "192","_","Outbound","Forest Hills",1,"39"
      """

      parsed = parse(blob, trip_route_direction)

      assert [
               %Variant{id: "1920018", replaced?: true}
             ] = parsed
    end
  end
end
