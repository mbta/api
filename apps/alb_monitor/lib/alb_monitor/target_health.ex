defmodule ALBMonitor.TargetHealth do
  @moduledoc """
  Builds the Elastic Load Balancing v2 `DescribeTargetHealth` request.

  This is the only ELB call we make, so we build it here rather than depend on
  `ex_aws_elastic_load_balancing`, whose 3.x release requires hackney 1.x.
  Only the fields `ALBMonitor.Monitor` reads are parsed.

  See https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_DescribeTargetHealth.html
  """

  # parses AWS <ErrorResponse> bodies into %{code:, message:, ...}; also imports ~x
  use ExAws.Operation.Query.Parser

  @version "2015-12-01"

  @spec describe_target_health(String.t()) :: ExAws.Operation.Query.t()
  def describe_target_health(target_group_arn) do
    %ExAws.Operation.Query{
      path: "/",
      params: %{
        "Action" => "DescribeTargetHealth",
        "Version" => @version,
        "TargetGroupArn" => target_group_arn
      },
      service: :elasticloadbalancing,
      action: :describe_target_health,
      parser: &parse/2
    }
  end

  @doc false
  def parse({:ok, %{body: xml} = resp}, :describe_target_health) do
    body =
      SweetXml.xpath(xml, ~x"//DescribeTargetHealthResponse",
        target_health_descriptions: [
          ~x"./DescribeTargetHealthResult/TargetHealthDescriptions/member"l,
          target_health: ~x"./TargetHealth/State/text()"s,
          targets: [~x"./Target"l, id: ~x"./Id/text()"s]
        ]
      )

    {:ok, Map.put(resp, :body, body)}
  end

  def parse(other, _action), do: other
end
