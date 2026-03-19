defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuoteRequestValidatorTest do
  use Pleroma.DataCase, async: true

  alias Pleroma.Web.ActivityPub.ObjectValidators.QuoteRequestValidator
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory

  describe "cast_and_validate/1" do
    setup do
      author = insert(:user, local: true)
      requester = insert(:user, local: false)

      {:ok, post_activity} = CommonAPI.post(author, %{status: "quotable post"})
      post_object = Pleroma.Object.normalize(post_activity, fetch: false)

      %{author: author, requester: requester, post_object: post_object}
    end

    test "validates a well-formed QuoteRequest", %{
      requester: requester,
      post_object: post_object
    } do
      data = %{
        "id" => "https://remote.example/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => requester.ap_id,
        "object" => post_object.data["id"],
        "instrument" => "https://remote.example/statuses/quoting-post"
      }

      changeset = QuoteRequestValidator.cast_and_validate(data)
      assert changeset.valid?
    end

    test "rejects non-QuoteRequest type", %{
      requester: requester,
      post_object: post_object
    } do
      data = %{
        "id" => "https://remote.example/activities/qr-1",
        "type" => "Follow",
        "actor" => requester.ap_id,
        "object" => post_object.data["id"]
      }

      changeset = QuoteRequestValidator.cast_and_validate(data)
      refute changeset.valid?
    end

    test "rejects when quoted object is not local", %{requester: requester} do
      data = %{
        "id" => "https://remote.example/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => requester.ap_id,
        "object" => "https://other-remote.example/objects/nonexistent"
      }

      changeset = QuoteRequestValidator.cast_and_validate(data)
      refute changeset.valid?
    end

    test "rejects missing required fields" do
      changeset = QuoteRequestValidator.cast_and_validate(%{"type" => "QuoteRequest"})
      refute changeset.valid?
    end

    test "extracts instrument from embedded object", %{
      requester: requester,
      post_object: post_object
    } do
      data = %{
        "id" => "https://remote.example/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => requester.ap_id,
        "object" => post_object.data["id"],
        "instrument" => %{
          "id" => "https://remote.example/statuses/quoting-post",
          "type" => "Note"
        }
      }

      changeset = QuoteRequestValidator.cast_and_validate(data)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :instrument) == "https://remote.example/statuses/quoting-post"
    end
  end
end
