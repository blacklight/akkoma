defmodule Pleroma.Web.ActivityPub.QuoteAuthorizationControllerTest do
  use Pleroma.Web.ConnCase, async: true

  alias Pleroma.QuoteAuthorization

  import Pleroma.Factory

  describe "GET /users/:nickname/quote_authorizations/:id" do
    test "returns the QuoteAuthorization JSON-LD document", %{conn: conn} do
      user = insert(:user)
      qa_id = Ecto.UUID.generate()
      ap_id = "#{user.ap_id}/quote_authorizations/#{qa_id}"

      data = %{
        "@context" => ["https://www.w3.org/ns/activitystreams"],
        "type" => "QuoteAuthorization",
        "id" => ap_id,
        "attributedTo" => user.ap_id,
        "interactionTarget" => "#{user.ap_id}/objects/post-1",
        "interactingObject" => "https://remote.example/statuses/1"
      }

      {:ok, _qa} =
        QuoteAuthorization.create(%{
          id: qa_id,
          ap_id: ap_id,
          user_id: user.id,
          quoted_ap_id: "#{user.ap_id}/objects/post-1",
          quoting_ap_id: "https://remote.example/statuses/1",
          data: data
        })

      response =
        conn
        |> put_req_header("accept", "application/activity+json")
        |> get("/users/#{user.nickname}/quote_authorizations/#{qa_id}")
        |> json_response(200)

      assert response["type"] == "QuoteAuthorization"
      assert response["id"] == ap_id
      assert response["attributedTo"] == user.ap_id
      assert response["interactionTarget"] == "#{user.ap_id}/objects/post-1"
      assert response["interactingObject"] == "https://remote.example/statuses/1"
    end

    test "returns 404 for non-existent authorization", %{conn: conn} do
      user = insert(:user)

      conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/users/#{user.nickname}/quote_authorizations/#{Ecto.UUID.generate()}")
      |> json_response(404)
    end

    test "returns 404 for non-existent user", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/activity+json")
      |> get("/users/nonexistent/quote_authorizations/#{Ecto.UUID.generate()}")
      |> json_response(404)
    end
  end
end
