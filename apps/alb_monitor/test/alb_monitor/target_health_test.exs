defmodule ALBMonitor.TargetHealthTest do
  use ExUnit.Case, async: true

  alias ALBMonitor.TargetHealth

  # response shape follows
  # https://docs.aws.amazon.com/elasticloadbalancing/latest/APIReference/API_DescribeTargetHealth.html
  @response """
  <DescribeTargetHealthResponse xmlns="http://elasticloadbalancing.amazonaws.com/doc/2015-12-01/">
    <DescribeTargetHealthResult>
      <TargetHealthDescriptions>
        <member>
          <HealthCheckPort>4000</HealthCheckPort>
          <TargetHealth>
            <State>healthy</State>
          </TargetHealth>
          <Target>
            <Port>4000</Port>
            <Id>10.0.0.1</Id>
          </Target>
        </member>
        <member>
          <HealthCheckPort>4000</HealthCheckPort>
          <TargetHealth>
            <State>draining</State>
            <Reason>Target.DeregistrationInProgress</Reason>
            <Description>Target deregistration is in progress</Description>
          </TargetHealth>
          <Target>
            <Port>4000</Port>
            <Id>10.0.0.2</Id>
          </Target>
        </member>
      </TargetHealthDescriptions>
    </DescribeTargetHealthResult>
    <ResponseMetadata>
      <RequestId>a1b2c3d4-0000-0000-0000-000000000000</RequestId>
    </ResponseMetadata>
  </DescribeTargetHealthResponse>
  """

  @error_response """
  <ErrorResponse xmlns="http://elasticloadbalancing.amazonaws.com/doc/2015-12-01/">
    <Error>
      <Type>Sender</Type>
      <Code>TargetGroupNotFound</Code>
      <Message>One or more target groups not found</Message>
    </Error>
    <RequestId>a1b2c3d4-0000-0000-0000-000000000000</RequestId>
  </ErrorResponse>
  """

  describe "describe_target_health/1" do
    test "builds a DescribeTargetHealth query for the target group" do
      assert %ExAws.Operation.Query{
               path: "/",
               service: :elasticloadbalancing,
               action: :describe_target_health,
               params: %{
                 "Action" => "DescribeTargetHealth",
                 "Version" => "2015-12-01",
                 "TargetGroupArn" => "arn:target-group"
               }
             } = TargetHealth.describe_target_health("arn:target-group")
    end
  end

  describe "parse/2" do
    test "parses each target's id and health state" do
      assert {:ok, %{status_code: 200, body: body}} =
               TargetHealth.parse(
                 {:ok, %{status_code: 200, body: @response}},
                 :describe_target_health
               )

      assert body == %{
               target_health_descriptions: [
                 %{target_health: "healthy", targets: [%{id: "10.0.0.1"}]},
                 %{target_health: "draining", targets: [%{id: "10.0.0.2"}]}
               ]
             }
    end

    test "parses AWS error responses" do
      assert {:error, {:http_error, 400, %{code: "TargetGroupNotFound", message: message}}} =
               TargetHealth.parse(
                 {:error, {:http_error, 400, %{body: @error_response}}},
                 :describe_target_health
               )

      assert message == "One or more target groups not found"
    end

    test "passes through other errors unchanged" do
      assert {:error, :timeout} = TargetHealth.parse({:error, :timeout}, :describe_target_health)
    end
  end
end
