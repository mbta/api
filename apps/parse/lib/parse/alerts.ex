defmodule Parse.Alerts do
  @moduledoc """
  Parse the Enhanced JSON feed from IBI.

  The enhanced feed is a JSON representation of the Protobuf data, with additional fields to represent data that extends
  the basic field set.
  """

  require Logger
  use Timex

  alias Model.Alert

  import :binary, only: [copy: 1]

  @behaviour Parse

  @spec parse(String.t()) :: [Alert.t()]
  def parse(body) do
    body
    |> Jason.decode!()
    |> parse_json()
  end

  @spec parse_json(%{optional(String.t()) => any}) :: [Model.Alert.t()]
  def parse_json(json_map) do
    for alert <- alert_json(json_map), active?(alert) do
      alert
      |> parse_alert()
      |> cleanup_description
    end
  end

  defp alert_json(%{"entity" => entities}) do
    for %{"id" => id, "alert" => alert} <- entities do
      Map.put(alert, "id", id)
    end
  end

  defp alert_json(%{"alerts" => alerts}) do
    alerts
  end

  def active?(%{"informed_entity" => [_ | _]}), do: true
  def active?(%{}), do: false

  def parse_alert(%{"id" => "695135"} = alert) do
    added_informed_entities = [
      %{
        "facility_id" => "park-DB-2205",
        "stop_id" => "DB-2205-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2258",
        "stop_id" => "DB-2258-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0168-garage",
        "stop_id" => "37150",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0183-garage",
        "stop_id" => "ER-0183-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0183-garage",
        "stop_id" => "ER-0183-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0312",
        "stop_id" => "ER-0312-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0148",
        "stop_id" => "FB-0148-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0230",
        "stop_id" => "FB-0230-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0275",
        "stop_id" => "FB-0275-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-royal",
        "stop_id" => "FR-0064-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-royal",
        "stop_id" => "FR-0064-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0115",
        "stop_id" => "FR-0115-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0253",
        "stop_id" => "FR-0253-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0394",
        "stop_id" => "FR-0394-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0494-garage",
        "stop_id" => "FR-0494-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0198",
        "stop_id" => "GB-0198-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0229",
        "stop_id" => "GB-0229-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0254",
        "stop_id" => "Manchester-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0162",
        "stop_id" => "GRB-0162-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0183",
        "stop_id" => "GRB-0183-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0233",
        "stop_id" => "GRB-0233-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-KB-0351",
        "stop_id" => "KB-0351-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0080",
        "stop_id" => "NB-0080-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0109",
        "stop_id" => "NB-0109-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0127",
        "stop_id" => "NB-0127-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NBM-0374",
        "stop_id" => "NBM-0374-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1969",
        "stop_id" => "NEC-1969-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2040",
        "stop_id" => "NEC-2040-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-station",
        "stop_id" => "NHRML-0218-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-station",
        "stop_id" => "NHRML-0218-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0245",
        "stop_id" => "PB-0245-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0125",
        "stop_id" => "WML-0125-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0135",
        "stop_id" => "WML-0135-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0067",
        "stop_id" => "WR-0067-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0075",
        "stop_id" => "WR-0075-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0099",
        "stop_id" => "WR-0099-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0163",
        "stop_id" => "WR-0163-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0228",
        "stop_id" => "WR-0228-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0325",
        "stop_id" => "WR-0325-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-butlr",
        "stop_id" => "70265",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-butlr",
        "stop_id" => "70266",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "5327",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "WR-0045-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-05",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-10",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-nqncy-garage",
        "stop_id" => "70098",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ogmnl",
        "stop_id" => "Oak Grove-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-11",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29006",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-claflin",
        "stop_id" => "FR-0064-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-claflin",
        "stop_id" => "FR-0064-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-aberjona",
        "stop_id" => "NHRML-0078-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-aberjona",
        "stop_id" => "NHRML-0078-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-garage",
        "stop_id" => "41031",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "70030",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-waban",
        "stop_id" => "70165",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52710",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wlsta",
        "stop_id" => "70100",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "15796",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "15798",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52715",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52716",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "70032",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "70059",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-0095",
        "stop_id" => "DB-0095-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-0095",
        "stop_id" => "NEC-2192-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2258",
        "stop_id" => "DB-2258-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2258",
        "stop_id" => "DB-2258-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2258",
        "stop_id" => "DB-2258-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0168-garage",
        "stop_id" => "ER-0168-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0208",
        "stop_id" => "ER-0208-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0208",
        "stop_id" => "ER-0208-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0109",
        "stop_id" => "FB-0109-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0230",
        "stop_id" => "FB-0230-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0137",
        "stop_id" => "FR-0137-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0219",
        "stop_id" => "FR-0219-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0361-garage",
        "stop_id" => "FR-0361-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0394",
        "stop_id" => "FR-0394-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0198",
        "stop_id" => "GB-0198-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0198",
        "stop_id" => "GB-0198-B3",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0229",
        "stop_id" => "GB-0229-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0254",
        "stop_id" => "GB-0254-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0316",
        "stop_id" => "GB-0316-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0064",
        "stop_id" => "NB-0064-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0072",
        "stop_id" => "NB-0072-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0080",
        "stop_id" => "NB-0080-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0109",
        "stop_id" => "NB-0109-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0120",
        "stop_id" => "91852",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0127",
        "stop_id" => "NB-0127-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0137",
        "stop_id" => "NB-0137-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NBM-0523",
        "stop_id" => "NBM-0523-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1659-garage",
        "stop_id" => "NEC-1659-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1919",
        "stop_id" => "NEC-1919-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-parkride",
        "stop_id" => "NHRML-0127-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-parkride",
        "stop_id" => "NHRML-0127-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-station",
        "stop_id" => "NHRML-0218-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0281",
        "stop_id" => "PB-0281-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0102",
        "stop_id" => "WML-0102-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0147",
        "stop_id" => "WML-0147-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0199",
        "stop_id" => "WML-0199-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0075",
        "stop_id" => "WR-0075-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0085",
        "stop_id" => "WR-0085-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0329",
        "stop_id" => "WR-0329-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14112",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14118",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "9070061",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "NEC-2237-05",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-matt",
        "stop_id" => "70275",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-miltt",
        "stop_id" => "70267",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "53270",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "70034",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "70035",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "70026",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "70027",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-08",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-lot",
        "stop_id" => "70104",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sdmnl",
        "stop_id" => "70054",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-06",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29003",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29005",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29007",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-carter",
        "stop_id" => "FR-0098-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0200-garage",
        "stop_id" => "MM-0200-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-airport",
        "stop_id" => "NHRML-0127-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-airport",
        "stop_id" => "NHRML-0127-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29011",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29012",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "70060",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-woodl-garage",
        "stop_id" => "70163",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52712",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52714",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-0095",
        "stop_id" => "NEC-2192-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0115-garage",
        "stop_id" => "ER-0115-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0362",
        "stop_id" => "ER-0362-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-royal",
        "stop_id" => "FR-0064-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-railroad",
        "stop_id" => "FR-0098-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-railroad",
        "stop_id" => "FR-0098-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0253",
        "stop_id" => "FR-0253-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0361-garage",
        "stop_id" => "FR-0361-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FRS-0109",
        "stop_id" => "FRS-0109-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0254",
        "stop_id" => "GB-0254-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0296",
        "stop_id" => "GB-0296-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0276",
        "stop_id" => "GRB-0276-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0186",
        "stop_id" => "39870",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0064",
        "stop_id" => "NB-0064-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0076",
        "stop_id" => "NB-0076-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0120",
        "stop_id" => "NB-0120-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-05",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2040",
        "stop_id" => "NEC-2040-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2173-garage",
        "stop_id" => "NEC-2173-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-parkride",
        "stop_id" => "NHRML-0127-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0152",
        "stop_id" => "NHRML-0152-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0212",
        "stop_id" => "PB-0212-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0356",
        "stop_id" => "PB-0356-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0125",
        "stop_id" => "WML-0125-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0135",
        "stop_id" => "WML-0135-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0252",
        "stop_id" => "WML-0252-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-B3",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0099",
        "stop_id" => "WR-0099-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0120",
        "stop_id" => "WR-0120-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0205",
        "stop_id" => "WR-0205-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0228",
        "stop_id" => "WR-0228-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14120",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14122",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-bcnfd",
        "stop_id" => "70176",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brkhl",
        "stop_id" => "70179",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-chhil",
        "stop_id" => "70172",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-eliot",
        "stop_id" => "70166",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "10642",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-mlmnl",
        "stop_id" => "5072",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "70206",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-nqncy-garage",
        "stop_id" => "3125",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "5879",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-shmnl",
        "stop_id" => "70087",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-12",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-claflin",
        "stop_id" => "FR-0064-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-carter",
        "stop_id" => "FR-0098-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0127-airport",
        "stop_id" => "NHRML-0127-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-eastern",
        "stop_id" => "NHRML-0218-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0442-garage",
        "stop_id" => "WML-0442-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29008",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52711",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52720",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-woodl-garage",
        "stop_id" => "70162",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "15799",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "15800",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-0095",
        "stop_id" => "FB-0095-05",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2205",
        "stop_id" => "DB-2205-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0128",
        "stop_id" => "ER-0128-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0208",
        "stop_id" => "ER-0208-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0227",
        "stop_id" => "ER-0227-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0362",
        "stop_id" => "ER-0362-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0275",
        "stop_id" => "FB-0275-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0303",
        "stop_id" => "FB-0303-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-railroad",
        "stop_id" => "FR-0098-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0115",
        "stop_id" => "FR-0115-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0137",
        "stop_id" => "FR-0137-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0201",
        "stop_id" => "FR-0201-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0219",
        "stop_id" => "FR-0219-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FS-0049",
        "stop_id" => "FS-0049-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0229",
        "stop_id" => "GB-0229-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0316",
        "stop_id" => "GB-0316-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0233",
        "stop_id" => "GRB-0233-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0276",
        "stop_id" => "GRB-0276-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0064",
        "stop_id" => "NB-0064-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0072",
        "stop_id" => "NB-0072-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0080",
        "stop_id" => "NB-0080-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0127",
        "stop_id" => "NB-0127-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1891-lot",
        "stop_id" => "NEC-1891-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1969",
        "stop_id" => "NEC-1969-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2108",
        "stop_id" => "NEC-2108-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2139",
        "stop_id" => "NEC-2139",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2139",
        "stop_id" => "NEC-2139-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2139",
        "stop_id" => "NEC-2139-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2139",
        "stop_id" => "SB-0150-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2203",
        "stop_id" => "NEC-2203-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0055",
        "stop_id" => "6303",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0055",
        "stop_id" => "NHRML-0055-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0073",
        "stop_id" => "NHRML-0073-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0073",
        "stop_id" => "NHRML-0073-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-waterfield",
        "stop_id" => "NHRML-0078-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-station",
        "stop_id" => "NHRML-0218-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0194",
        "stop_id" => "PB-0194-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-SB-0189",
        "stop_id" => "SB-0189-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0214",
        "stop_id" => "WML-0214-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0252",
        "stop_id" => "WML-0252-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0442-lot",
        "stop_id" => "WML-0442-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0067",
        "stop_id" => "WR-0067-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0205",
        "stop_id" => "WR-0205-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0228",
        "stop_id" => "WR-0228-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0264",
        "stop_id" => "WR-0264-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0325",
        "stop_id" => "WR-0325-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0329",
        "stop_id" => "WR-0329-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "MM-0109-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-chhil",
        "stop_id" => "70173",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "NEC-2237-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-miltt",
        "stop_id" => "70268",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-nqncy-garage",
        "stop_id" => "70097",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ogmnl",
        "stop_id" => "9328",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "70051",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-river",
        "stop_id" => "70160",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sdmnl",
        "stop_id" => "70053",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29001",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0117-ellis",
        "stop_id" => "ER-0117-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "MM-0109-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-garage",
        "stop_id" => "70104",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29010",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "70031",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52712",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52714",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wlsta",
        "stop_id" => "70099",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "70059",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "15796",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "15798",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0208",
        "stop_id" => "ER-0208-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0276",
        "stop_id" => "ER-0276-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0109",
        "stop_id" => "FB-0109-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0118",
        "stop_id" => "FB-0118-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0148",
        "stop_id" => "Norwood Central-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0132",
        "stop_id" => "FR-0132-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0167",
        "stop_id" => "FR-0167-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0253",
        "stop_id" => "FR-0253-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0301",
        "stop_id" => "FR-0301-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0301",
        "stop_id" => "FR-0301-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0394",
        "stop_id" => "FR-0394-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0451-garage",
        "stop_id" => "FR-0451-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-3338-garage",
        "stop_id" => "FR-3338-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0316",
        "stop_id" => "GB-0316-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0118",
        "stop_id" => "GRB-0118-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0146",
        "stop_id" => "GRB-0146-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0150",
        "stop_id" => "MM-0150-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0186",
        "stop_id" => "MM-0186-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0200-lot",
        "stop_id" => "MM-0200-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0120",
        "stop_id" => "NB-0120-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0127",
        "stop_id" => "NB-0127-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0137",
        "stop_id" => "NB-0137-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0137",
        "stop_id" => "NB-0137-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NBM-0374",
        "stop_id" => "NBM-0374",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1659-garage",
        "stop_id" => "NEC-1659-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1969",
        "stop_id" => "NEC-1969-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2203",
        "stop_id" => "NEC-2203-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0055",
        "stop_id" => "6316",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0055",
        "stop_id" => "NHRML-0055-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0073",
        "stop_id" => "NHRML-0073-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-waterfield",
        "stop_id" => "NHRML-0078-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-waterfield",
        "stop_id" => "NHRML-0078-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0177",
        "stop_id" => "WML-0177-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0199",
        "stop_id" => "WML-0199-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0274",
        "stop_id" => "WML-0274-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0340",
        "stop_id" => "WML-0340-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0340",
        "stop_id" => "WML-0340-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0067",
        "stop_id" => "WR-0067-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0085",
        "stop_id" => "WR-0085-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0120",
        "stop_id" => "WR-0120-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0163",
        "stop_id" => "WR-0163-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0205",
        "stop_id" => "WR-0205-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "70061",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "Alewife-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-bcnfd",
        "stop_id" => "70177",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-bmmnl",
        "stop_id" => "70056",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brkhl",
        "stop_id" => "70178",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "38671",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-eliot",
        "stop_id" => "70167",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-matt",
        "stop_id" => "18511",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ogmnl",
        "stop_id" => "70036",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ogmnl",
        "stop_id" => "WR-0053-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "5880",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-lot",
        "stop_id" => "70103",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-river",
        "stop_id" => "38155",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-08",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-10",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-13",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-eastern",
        "stop_id" => "NHRML-0218-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-eastern",
        "stop_id" => "NHRML-0218-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0091-newton",
        "stop_id" => "WML-0091-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "38671",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-waban",
        "stop_id" => "70164",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "70033",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "15797",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52713",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-0095",
        "stop_id" => "FB-0095-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2205",
        "stop_id" => "DB-2205-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0117-garage",
        "stop_id" => "ER-0117-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0128",
        "stop_id" => "ER-0128-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0128",
        "stop_id" => "ER-0128-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0168-garage",
        "stop_id" => "ER-0168-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0183-garage",
        "stop_id" => "ER-0183-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0227",
        "stop_id" => "ER-0227-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0312",
        "stop_id" => "ER-0312-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0148",
        "stop_id" => "FB-0148-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0191",
        "stop_id" => "FB-0191-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0275",
        "stop_id" => "FB-0275-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0394",
        "stop_id" => "FR-0394-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0451-garage",
        "stop_id" => "FR-0451-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0296",
        "stop_id" => "GB-0296-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0353",
        "stop_id" => "GB-0353-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-KB-0351",
        "stop_id" => "KB-0351-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0150",
        "stop_id" => "4255",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0186",
        "stop_id" => "MM-0186-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0200-lot",
        "stop_id" => "MM-0200-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0219",
        "stop_id" => "MM-0219-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0356",
        "stop_id" => "MM-0356-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0076",
        "stop_id" => "NB-0076-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NBM-0374",
        "stop_id" => "NBM-0374-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NBM-0546",
        "stop_id" => "NBM-0546-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1768-garage",
        "stop_id" => "NEC-1768-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1891-lot",
        "stop_id" => "NEC-1891-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1891-lot",
        "stop_id" => "NEC-1891-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2108",
        "stop_id" => "NEC-2108-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0152",
        "stop_id" => "NHRML-0152-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-station",
        "stop_id" => "NHRML-0218-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0254-garage",
        "stop_id" => "NHRML-0254-04",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0158",
        "stop_id" => "PB-0158-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0158",
        "stop_id" => "South Weymouth-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0177",
        "stop_id" => "WML-0177-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0214",
        "stop_id" => "WML-0214-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0274",
        "stop_id" => "WML-0274-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0364",
        "stop_id" => "WML-0364-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0075",
        "stop_id" => "WR-0075-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0085",
        "stop_id" => "WR-0085-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0264",
        "stop_id" => "WR-0264-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0329",
        "stop_id" => "WR-0329-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14123",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "MM-0109-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "70001",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "875",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-matt",
        "stop_id" => "185",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-matt",
        "stop_id" => "70276",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-07",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-09",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "15880",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-lot",
        "stop_id" => "41031",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "70079",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "84611",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29002",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "MM-0109-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29009",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52715",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52716",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "70032",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52710",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "70060",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-DB-2205",
        "stop_id" => "DB-2205-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0115-garage",
        "stop_id" => "14748",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0362",
        "stop_id" => "ER-0362-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0143",
        "stop_id" => "FB-0143-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0303",
        "stop_id" => "FB-0303-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-royal",
        "stop_id" => "FR-0064-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0115",
        "stop_id" => "FR-0115-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0132",
        "stop_id" => "FR-0132-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0201",
        "stop_id" => "FR-0201-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0301",
        "stop_id" => "FR-0301-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0494-garage",
        "stop_id" => "FR-0494-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-3338-garage",
        "stop_id" => "FR-3338-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FRS-0054",
        "stop_id" => "FRS-0054-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FS-0049",
        "stop_id" => "FS-0049-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0254",
        "stop_id" => "GB-0254-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0296",
        "stop_id" => "GB-0296-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0353",
        "stop_id" => "GB-0353-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GRB-0199",
        "stop_id" => "GRB-0199-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0076",
        "stop_id" => "NB-0076-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0076",
        "stop_id" => "NB-0076-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0080",
        "stop_id" => "NB-0080-B3",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0080",
        "stop_id" => "NB-0080-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0109",
        "stop_id" => "NB-0109-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0120",
        "stop_id" => "NB-0120-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0137",
        "stop_id" => "NB-0137-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1919",
        "stop_id" => "NEC-1919-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2173-garage",
        "stop_id" => "NEC-2173-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0254-garage",
        "stop_id" => "NHRML-0254-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0281",
        "stop_id" => "PB-0281-CS",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0147",
        "stop_id" => "WML-0147-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0214",
        "stop_id" => "WML-0214-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0252",
        "stop_id" => "WML-0252-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0364",
        "stop_id" => "WML-0364-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0075",
        "stop_id" => "WR-0075-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0075",
        "stop_id" => "WR-0075-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0085",
        "stop_id" => "WR-0085-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0099",
        "stop_id" => "WR-0099-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0099",
        "stop_id" => "WR-0099-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-bmmnl",
        "stop_id" => "70055",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "70105",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "Braintree-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "Forest Hills-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-longw",
        "stop_id" => "70182",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "70052",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "70080",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-03",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-05",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0117-ellis",
        "stop_id" => "ER-0117-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0064-claflin",
        "stop_id" => "FR-0064-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-eastern",
        "stop_id" => "NHRML-0218-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "70105",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "Braintree-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-qamnl-garage",
        "stop_id" => "70103",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29013",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-lot",
        "stop_id" => "52713",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "15799",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-nshore",
        "stop_id" => "15800",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "70033",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0115-garage",
        "stop_id" => "ER-0115-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0117-garage",
        "stop_id" => "ER-0117-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0128",
        "stop_id" => "ER-0128-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0208",
        "stop_id" => "ER-0208-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0227",
        "stop_id" => "ER-0227-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ER-0276",
        "stop_id" => "ER-0276-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0118",
        "stop_id" => "Dedham Corp Center-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0118",
        "stop_id" => "FB-0118-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0125",
        "stop_id" => "FB-0125-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0125",
        "stop_id" => "FB-0125-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0143",
        "stop_id" => "FB-0143-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FB-0191",
        "stop_id" => "FB-0191-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-railroad",
        "stop_id" => "FR-0098-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0115",
        "stop_id" => "FR-0115-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0167",
        "stop_id" => "FR-0167-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0167",
        "stop_id" => "FR-0167-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0201",
        "stop_id" => "FR-0201-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0201",
        "stop_id" => "FR-0201-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0219",
        "stop_id" => "FR-0219-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0361-garage",
        "stop_id" => "FR-0361-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0361-garage",
        "stop_id" => "FR-0361-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0451-garage",
        "stop_id" => "FR-0451-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0198",
        "stop_id" => "GB-0198-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0229",
        "stop_id" => "GB-0229-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0296",
        "stop_id" => "GB-0296-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-GB-0296",
        "stop_id" => "GB-0296-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MBS-0350",
        "stop_id" => "MBS-0350-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0277",
        "stop_id" => "MM-0277-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0064",
        "stop_id" => "NB-0064-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0072",
        "stop_id" => "NB-0072-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NB-0072",
        "stop_id" => "NB-0072-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1768-garage",
        "stop_id" => "NEC-1768-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-1851-garage",
        "stop_id" => "NEC-1851-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NEC-2139",
        "stop_id" => "SB-0150-06",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0152",
        "stop_id" => "NHRML-0152-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0254-garage",
        "stop_id" => "NHRML-0254-B",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-PB-0281",
        "stop_id" => "PB-0281-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-SB-0156",
        "stop_id" => "SB-0156-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WML-0091-wash",
        "stop_id" => "WML-0091-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0062",
        "stop_id" => "WR-0062-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0067",
        "stop_id" => "WR-0067-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0163",
        "stop_id" => "WR-0163-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0205",
        "stop_id" => "WR-0205-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0264",
        "stop_id" => "WR-0264-B2",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-WR-0325",
        "stop_id" => "WR-0325-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "14121",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-alfcl-garage",
        "stop_id" => "Alewife-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-lot-a",
        "stop_id" => "Braintree-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-forhl",
        "stop_id" => "Forest Hills-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-longw",
        "stop_id" => "70183",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "70205",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-north-garage",
        "stop_id" => "BNT-0000-06",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-ogmnl",
        "stop_id" => "Oak Grove-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-orhte",
        "stop_id" => "15879",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-river",
        "stop_id" => "70161",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-shmnl",
        "stop_id" => "70088",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "74611",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "74617",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-07",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sstat-garage",
        "stop_id" => "NEC-2287-09",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-sull",
        "stop_id" => "29004",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-carter",
        "stop_id" => "FR-0098-B0",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-FR-0098-carter",
        "stop_id" => "FR-0098-B1",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-MM-0200-garage",
        "stop_id" => "MM-0200-S",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0078-aberjona",
        "stop_id" => "NHRML-0078-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-NHRML-0218-eastern",
        "stop_id" => "NHRML-0218-01",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-brntn-garage",
        "stop_id" => "Braintree-02",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52711",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-welln-garage",
        "stop_id" => "52720",
        "activities" => ["PARK_CAR"]
      },
      %{
        "facility_id" => "park-wondl-garage",
        "stop_id" => "15797",
        "activities" => ["PARK_CAR"]
      },
      %{
        "route_type" => 1,
        # these are the activities that the existing informed entities have from alerts UI
        "activities" => ["BOARD", "EXIT", "RIDE"]
      }
    ]

    %Alert{
      id: Map.get(alert, "id"),
      effect: "PARKING_ISSUE",
      cause: cause(alert),
      header: alert |> Map.get("header_text") |> translated_text,
      short_header: alert |> Map.get("short_header_text") |> translated_text,
      description: alert |> Map.get("description_text") |> translated_text,
      banner: alert |> Map.get("banner_text") |> translated_text(default: nil),
      severity: Map.get(alert, "severity"),
      created_at: alert |> Map.get("created_timestamp") |> unix_timestamp,
      updated_at: alert |> Map.get("last_modified_timestamp") |> unix_timestamp,
      active_period:
        alert
        |> Map.get("active_period", [])
        |> fallback_active_period()
        |> Enum.map(&active_period/1),
      informed_entity:
        Enum.map(Map.get(alert, "informed_entity") ++ added_informed_entities, &informed_entity/1),
      service_effect: alert |> Map.get("service_effect_text") |> translated_text,
      timeframe: alert |> Map.get("timeframe_text") |> translated_text(default: nil),
      duration_certainty: alert |> Map.get("duration_certainty"),
      lifecycle: alert |> Map.get("alert_lifecycle") |> lifecycle,
      url: alert |> Map.get("url") |> translated_text(default: nil),
      image: alert |> Map.get("image") |> translated_image(default: nil),
      image_alternative_text:
        alert |> Map.get("image_alternative_text") |> translated_text(default: nil),
      closed_timestamp: alert |> Map.get("closed_timestamp") |> unix_timestamp(),
      last_push_notification_timestamp:
        alert |> Map.get("last_push_notification_timestamp") |> unix_timestamp(),
      reminder_times: alert |> Map.get("reminder_times") |> map_optional(&unix_timestamp/1)
    }
  end

  def parse_alert(alert) do
    %Alert{
      id: Map.get(alert, "id"),
      effect: alert |> Map.get("effect_detail") |> copy,
      cause: cause(alert),
      header: alert |> Map.get("header_text") |> translated_text,
      short_header: alert |> Map.get("short_header_text") |> translated_text,
      description: alert |> Map.get("description_text") |> translated_text,
      banner: alert |> Map.get("banner_text") |> translated_text(default: nil),
      severity: Map.get(alert, "severity"),
      created_at: alert |> Map.get("created_timestamp") |> unix_timestamp,
      updated_at: alert |> Map.get("last_modified_timestamp") |> unix_timestamp,
      active_period:
        alert
        |> Map.get("active_period", [])
        |> fallback_active_period()
        |> Enum.map(&active_period/1),
      informed_entity: alert |> Map.get("informed_entity") |> Enum.map(&informed_entity/1),
      service_effect: alert |> Map.get("service_effect_text") |> translated_text,
      timeframe: alert |> Map.get("timeframe_text") |> translated_text(default: nil),
      duration_certainty: alert |> Map.get("duration_certainty"),
      lifecycle: alert |> Map.get("alert_lifecycle") |> lifecycle,
      url: alert |> Map.get("url") |> translated_text(default: nil),
      image: alert |> Map.get("image") |> translated_image(default: nil),
      image_alternative_text:
        alert |> Map.get("image_alternative_text") |> translated_text(default: nil),
      closed_timestamp: alert |> Map.get("closed_timestamp") |> unix_timestamp(),
      last_push_notification_timestamp:
        alert |> Map.get("last_push_notification_timestamp") |> unix_timestamp(),
      reminder_times: alert |> Map.get("reminder_times") |> map_optional(&unix_timestamp/1)
    }
  end

  defp cause(%{"cause_detail" => cause}) do
    copy(cause)
  end

  defp cause(%{"cause" => cause}) do
    copy(cause)
  end

  defp cause(alert) do
    Logger.error("No cause found in alert: #{inspect(alert)}")
    ""
  end

  def lifecycle("ONGOING"), do: "ONGOING"
  def lifecycle("UPCOMING"), do: "UPCOMING"
  def lifecycle(<<"UPCOMING", _::binary-1, "ONGOING">>), do: "ONGOING_UPCOMING"
  def lifecycle(<<"ONGOING", _::binary-1, "UPCOMING">>), do: "ONGOING_UPCOMING"
  def lifecycle("NEW"), do: "NEW"
  def lifecycle(_), do: "UNKNOWN"

  defp translated_text(translations, opts \\ []) do
    opts =
      opts
      |> Map.new()
      |> Map.put_new(:default, "")

    do_translated_text(translations, opts)
  end

  defp do_translated_text([], %{default: default}) do
    default
  end

  defp do_translated_text(nil, %{default: default}) do
    default
  end

  defp do_translated_text(%{"translation" => translations}, opts) do
    do_translated_text(translations, opts)
  end

  defp do_translated_text([%{"language" => "en", "text" => text} | _], _) do
    copy(text)
  end

  defp do_translated_text([%{"translation" => %{"language" => "en", "text" => text}} | _], _) do
    copy(text)
  end

  defp do_translated_text([_wrong_language | rest], opts) do
    do_translated_text(rest, opts)
  end

  defp translated_image(localizations, opts) do
    opts =
      opts
      |> Map.new()
      |> Map.put_new(:default, "")

    do_localized_image(localizations, opts)
  end

  defp do_localized_image([], %{default: default}) do
    default
  end

  defp do_localized_image(nil, %{default: default}) do
    default
  end

  defp do_localized_image(%{"localized_image" => [%{"url" => url}]}, _) do
    copy(url)
  end

  defp do_localized_image(%{"localized_image" => [_ | _] = translations}, %{default: default}) do
    translations =
      translations
      |> Enum.filter(&(&1["language"] == "en" or &1["language"] == nil))
      |> Enum.sort(:desc)

    case translations do
      [] -> default
      [first | _] -> first["url"]
    end
  end

  defp fallback_active_period([]) do
    # some alerts authoring tools remove all active periods to signal that an alert is closed,
    # but the GTFS-RT spec says that an alert with no active periods should actually be treated as
    # always active until it is removed from the feed.
    # we always specify active periods for current and future alerts, so we know that an alert
    # with no active periods is actually closed.
    [%{"start" => 0, "end" => 0}]
  end

  defp fallback_active_period(list), do: list

  defp active_period(%{"start" => start, "end" => stop}) do
    {unix_timestamp(start), unix_timestamp(stop)}
  end

  defp active_period(%{"start" => start}) do
    {unix_timestamp(start), nil}
  end

  defp active_period(%{"end" => stop}) do
    {nil, unix_timestamp(stop)}
  end

  defp active_period(%{}) do
    {nil, nil}
  end

  defp activities(list) when is_list(list), do: Enum.map(list, &copy/1)

  defp map_optional(nil, _), do: nil
  defp map_optional(list, f), do: Enum.map(list, f)

  defp informed_entity(json) do
    %{}
    |> build_informed_entity(json, ["activities"], :activities, &activities/1)
    |> build_informed_entity(json, ["direction_id"], :direction_id)
    |> build_informed_entity(json, ["facility_id"], :facility, &copy/1)
    |> build_informed_entity(json, ["route_id"], :route, &copy/1)
    |> build_informed_entity(json, ["route_type"], :route_type)
    |> build_informed_entity(json, ["stop_id"], :stop, &copy/1)
    |> build_informed_entity(json, ["trip", "direction_id"], :direction_id)
    |> build_informed_entity(json, ["trip", "trip_id"], :trip, &copy/1)
  end

  defp build_informed_entity(entity, json, access, entity_field, mapper \\ fn x -> x end)

  defp build_informed_entity(entity, json, access, :route_type, mapper) do
    case get_in(json, access) do
      nil ->
        add_route_type(entity)

      value ->
        Map.put(entity, :route_type, mapper.(value))
    end
  end

  defp build_informed_entity(entity, json, access, entity_field, mapper) do
    case get_in(json, access) do
      nil ->
        entity

      value ->
        Map.put(entity, entity_field, mapper.(value))
    end
  end

  defp add_route_type(%{route: nil} = entity), do: entity

  defp add_route_type(%{route: route} = entity)
       when route in ["Green", "Green-B", "Green-C", "Green-D", "Green-E", "Mattapan"] do
    Map.put(entity, :route_type, 0)
  end

  defp add_route_type(%{route: route} = entity) when route in ["Blue", "Red", "Orange"] do
    Map.put(entity, :route_type, 1)
  end

  defp add_route_type(%{route: "CR-" <> _} = entity) do
    Map.put(entity, :route_type, 2)
  end

  defp add_route_type(%{route: "Boat" <> _} = entity) do
    Map.put(entity, :route_type, 4)
  end

  defp add_route_type(%{route: _} = entity) do
    Map.put(entity, :route_type, 3)
  end

  defp add_route_type(entity), do: entity

  defp unix_timestamp(nil), do: nil

  defp unix_timestamp(seconds_since_epoch) do
    seconds_since_epoch
    |> DateTime.from_unix!()
    |> Timex.to_datetime("America/New_York")
  end

  defp cleanup_description(%Alert{} = alert) do
    # strip the header from the description
    prefix = "#{alert.header}."

    description =
      alert.description
      |> String.replace_prefix(prefix, "")
      |> String.trim_leading()

    if description == "" do
      %{alert | description: nil}
    else
      %{alert | description: description}
    end
  end
end
