defmodule Pleroma.QuoteAuthorizationTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.QuoteAuthorization

  import Pleroma.Factory

  describe "create/1" do
    test "creates a quote authorization with valid params" do
      user = insert(:user)

      params = %{
        ap_id: "#{user.ap_id}/quote_authorizations/test-uuid",
        user_id: user.id,
        quoted_ap_id: "#{user.ap_id}/objects/quoted-post",
        quoting_ap_id: "https://remote.example/users/bob/statuses/1",
        data: %{
          "type" => "QuoteAuthorization",
          "id" => "#{user.ap_id}/quote_authorizations/test-uuid",
          "attributedTo" => user.ap_id,
          "interactionTarget" => "#{user.ap_id}/objects/quoted-post",
          "interactingObject" => "https://remote.example/users/bob/statuses/1"
        }
      }

      assert {:ok, %QuoteAuthorization{} = qa} = QuoteAuthorization.create(params)
      assert qa.ap_id == params.ap_id
      assert qa.user_id == user.id
      assert qa.quoted_ap_id == params.quoted_ap_id
      assert qa.quoting_ap_id == params.quoting_ap_id
      assert qa.data["type"] == "QuoteAuthorization"
    end

    test "fails with missing required fields" do
      assert {:error, changeset} = QuoteAuthorization.create(%{})
      assert errors_on(changeset) |> Map.has_key?(:ap_id)
      assert errors_on(changeset) |> Map.has_key?(:user_id)
      assert errors_on(changeset) |> Map.has_key?(:quoted_ap_id)
      assert errors_on(changeset) |> Map.has_key?(:quoting_ap_id)
      assert errors_on(changeset) |> Map.has_key?(:data)
    end

    test "fails with duplicate ap_id" do
      user = insert(:user)

      params = %{
        ap_id: "#{user.ap_id}/quote_authorizations/test-uuid",
        user_id: user.id,
        quoted_ap_id: "#{user.ap_id}/objects/quoted-post",
        quoting_ap_id: "https://remote.example/users/bob/statuses/1",
        data: %{"type" => "QuoteAuthorization"}
      }

      assert {:ok, _} = QuoteAuthorization.create(params)
      assert {:error, changeset} = QuoteAuthorization.create(params)
      assert errors_on(changeset) |> Map.has_key?(:ap_id)
    end
  end

  describe "get_by_ap_id/1" do
    test "returns the authorization by ap_id" do
      user = insert(:user)
      ap_id = "#{user.ap_id}/quote_authorizations/lookup-test"

      {:ok, qa} =
        QuoteAuthorization.create(%{
          ap_id: ap_id,
          user_id: user.id,
          quoted_ap_id: "#{user.ap_id}/objects/post",
          quoting_ap_id: "https://remote.example/statuses/1",
          data: %{"type" => "QuoteAuthorization"}
        })

      assert %QuoteAuthorization{id: id} = QuoteAuthorization.get_by_ap_id(ap_id)
      assert id == qa.id
    end

    test "returns nil for unknown ap_id" do
      assert nil == QuoteAuthorization.get_by_ap_id("https://nonexistent/qa/1")
    end
  end

  describe "get_by_quoted_and_quoting/2" do
    test "returns the authorization matching both AP IDs" do
      user = insert(:user)
      quoted = "#{user.ap_id}/objects/post-1"
      quoting = "https://remote.example/statuses/42"

      {:ok, qa} =
        QuoteAuthorization.create(%{
          ap_id: "#{user.ap_id}/quote_authorizations/pair-test",
          user_id: user.id,
          quoted_ap_id: quoted,
          quoting_ap_id: quoting,
          data: %{"type" => "QuoteAuthorization"}
        })

      assert %QuoteAuthorization{id: id} =
               QuoteAuthorization.get_by_quoted_and_quoting(quoted, quoting)

      assert id == qa.id
    end

    test "returns nil when no match" do
      assert nil == QuoteAuthorization.get_by_quoted_and_quoting("a", "b")
    end
  end

  describe "delete_by_ap_id/1" do
    test "deletes an existing authorization" do
      user = insert(:user)
      ap_id = "#{user.ap_id}/quote_authorizations/delete-test"

      {:ok, _} =
        QuoteAuthorization.create(%{
          ap_id: ap_id,
          user_id: user.id,
          quoted_ap_id: "#{user.ap_id}/objects/post",
          quoting_ap_id: "https://remote.example/statuses/1",
          data: %{"type" => "QuoteAuthorization"}
        })

      assert {:ok, _} = QuoteAuthorization.delete_by_ap_id(ap_id)
      assert nil == QuoteAuthorization.get_by_ap_id(ap_id)
    end

    test "returns error for non-existent ap_id" do
      assert {:error, :not_found} = QuoteAuthorization.delete_by_ap_id("https://nope/qa/1")
    end
  end
end
