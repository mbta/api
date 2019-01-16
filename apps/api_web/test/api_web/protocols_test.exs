defmodule ApiWeb.ProtocolsTest do
  use ExUnit.Case, async: true
  import ApiAccounts.Changeset

  @mod Phoenix.HTML.FormData.ApiAccounts.Changeset

  test "to_form/4" do
    changeset =
      %ApiAccounts.User{}
      |> cast(%{}, ~w())
      |> validate_required(:name)

    assert_raise ArgumentError, fn ->
      @mod.to_form(changeset, @mod.to_form(changeset, as: "test"), :name, [])
    end
  end
end
