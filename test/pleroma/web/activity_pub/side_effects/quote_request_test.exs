defmodule Pleroma.Web.ActivityPub.SideEffects.QuoteRequestTest do
  use Pleroma.DataCase, async: false
  use Oban.Testing, repo: Pleroma.Repo

  alias Pleroma.Activity
  alias Pleroma.Object
  alias Pleroma.QuoteAuthorization
  alias Pleroma.Web.ActivityPub.Builder
  alias Pleroma.Web.ActivityPub.SideEffects
  alias Pleroma.Web.CommonAPI

  import Pleroma.Factory
  import Mock

  describe "QuoteRequest side effects" do
    setup do
      author = insert(:user, local: true)
      requester = insert(:user, local: false)

      {:ok, post_activity} = CommonAPI.post(author, %{status: "original post"})
      post_object = Object.normalize(post_activity, fetch: false)

      %{author: author, requester: requester, post_object: post_object}
    end

    test "auto-approves and creates QuoteAuthorization", %{
      author: author,
      requester: requester,
      post_object: post_object
    } do
      quote_request_data = %{
        "id" => "https://remote.example/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => requester.ap_id,
        "object" => post_object.data["id"],
        "instrument" => "https://remote.example/statuses/quoting-post",
        "to" => [author.ap_id]
      }

      {:ok, activity} =
        Pleroma.Repo.insert(%Activity{
          data: quote_request_data,
          local: false,
          actor: requester.ap_id,
          recipients: [author.ap_id]
        })

      with_mock Pleroma.Web.ActivityPub.Pipeline,
        common_pipeline: fn data, _opts ->
          {:ok,
           %Activity{
             data: data,
             local: true,
             actor: data["actor"],
             recipients: data["to"] || []
           }, []}
        end do
        {:ok, _activity, _meta} = SideEffects.handle(activity)

        # Verify a QuoteAuthorization was created
        qa =
          QuoteAuthorization.get_by_quoted_and_quoting(
            post_object.data["id"],
            "https://remote.example/statuses/quoting-post"
          )

        assert qa != nil
        assert qa.user_id == author.id
        assert qa.data["type"] == "QuoteAuthorization"
        assert qa.data["interactionTarget"] == post_object.data["id"]
        assert qa.data["interactingObject"] == "https://remote.example/statuses/quoting-post"
        assert qa.data["attributedTo"] == author.ap_id

        # Verify Pipeline.common_pipeline was called with an Accept
        assert_called(
          Pleroma.Web.ActivityPub.Pipeline.common_pipeline(
            :meck.is(fn data -> data["type"] == "Accept" end),
            :_
          )
        )
      end
    end
  end

  describe "Accept for QuoteRequest side effects" do
    setup do
      user = insert(:user, local: true)
      remote = insert(:user, local: false)

      {:ok, post_activity} = CommonAPI.post(user, %{status: "quoting a remote post"})
      post_object = Object.normalize(post_activity, fetch: false)

      %{user: user, remote: remote, post_object: post_object}
    end

    test "stores quoteAuthorization on the local object", %{
      user: user,
      remote: remote,
      post_object: post_object
    } do
      # Simulate a QuoteRequest activity that was previously sent
      quote_request_data = %{
        "id" => "#{user.ap_id}/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => user.ap_id,
        "object" => "https://remote.example/objects/quoted-post",
        "instrument" => post_object.data["id"],
        "to" => [remote.ap_id]
      }

      {:ok, qr_activity} =
        Pleroma.Repo.insert(%Activity{
          data: quote_request_data,
          local: true,
          actor: user.ap_id,
          recipients: [remote.ap_id]
        })

      # Simulate receiving an Accept with result
      accept_data = %{
        "type" => "Accept",
        "actor" => remote.ap_id,
        "object" => qr_activity.data["id"],
        "result" => "https://remote.example/users/bob/quote_authorizations/abc-123",
        "to" => [user.ap_id]
      }

      accept_activity = %Activity{
        data: accept_data,
        local: false,
        actor: remote.ap_id,
        recipients: [user.ap_id]
      }

      {:ok, _activity, _meta} = SideEffects.handle(accept_activity)

      # Verify the quoteAuthorization and approval state were stored on the local object
      updated_object = Object.get_cached_by_ap_id(post_object.data["id"])

      assert updated_object.data["quoteAuthorization"] ==
               "https://remote.example/users/bob/quote_authorizations/abc-123"

      assert updated_object.data["quoteApprovalState"] == "accepted"
    end
  end

  describe "Reject for QuoteRequest side effects" do
    setup do
      user = insert(:user, local: true)
      remote = insert(:user, local: false)

      {:ok, post_activity} = CommonAPI.post(user, %{status: "quoting a remote post"})
      post_object = Object.normalize(post_activity, fetch: false)

      %{user: user, remote: remote, post_object: post_object}
    end

    test "sets quoteApprovalState to rejected", %{
      user: user,
      remote: remote,
      post_object: post_object
    } do
      quote_request_data = %{
        "id" => "#{user.ap_id}/activities/qr-1",
        "type" => "QuoteRequest",
        "actor" => user.ap_id,
        "object" => "https://remote.example/objects/quoted-post",
        "instrument" => post_object.data["id"],
        "to" => [remote.ap_id]
      }

      {:ok, qr_activity} =
        Pleroma.Repo.insert(%Activity{
          data: quote_request_data,
          local: true,
          actor: user.ap_id,
          recipients: [remote.ap_id]
        })

      reject_data = %{
        "type" => "Reject",
        "actor" => remote.ap_id,
        "object" => qr_activity.data["id"],
        "to" => [user.ap_id]
      }

      reject_activity = %Activity{
        data: reject_data,
        local: false,
        actor: remote.ap_id,
        recipients: [user.ap_id]
      }

      {:ok, _activity, _meta} = SideEffects.handle(reject_activity)

      updated_object = Object.get_cached_by_ap_id(post_object.data["id"])
      assert updated_object.data["quoteApprovalState"] == "rejected"
    end
  end
end
