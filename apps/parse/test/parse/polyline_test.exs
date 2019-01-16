defmodule Parse.PolylineTest do
  use ExUnit.Case, async: true
  import Parse.Polyline

  @blob """
  "shape_id","shape_pt_lat","shape_pt_lon","shape_pt_sequence","shape_dist_traveled"
  "cf00001",41.660225,-70.276583,1,""
  "cf00001",41.683585,-70.258956,2,""
  "cf00001",41.692367,-70.256982,3,""
  "cf00001",41.699288,-70.259557,4,""
  "cf00001",41.700506,-70.262682,5,""
  "cf00001",41.700554,-70.265043,6,""
  "cf00001",41.696837,-70.279333,7,""
  "cf00001",41.697878,-70.300469,8,""
  "cf00001",41.701739,-70.319245,9,""
  "cf00001",41.700282,-70.343428,10,""
  "cf00001",41.701403,-70.354543,11,""
  "cf00001",41.702508,-70.360386,12,""
  "cf00001",41.708372,-70.377788,13,""
  "cf00001",41.731347,-70.433868,14,""
  "cf00001",41.744468,-70.455551,15,""
  "cf00001",41.746093,-70.464638,16,""
  "cf00001",41.751929,-70.477781,17,""
  "cf00001",41.75517,-70.48748,18,""
  """

  describe "parse/1" do
    test "test returns a list of shapes" do
      parsed = parse(@blob)

      assert [
               %Parse.Polyline{id: "cf00001", polyline: polyline}
             ] = parsed

      # slight loss of precision
      assert [{-70.27658, 41.66022} | _] = Polyline.decode(polyline)
    end
  end
end
