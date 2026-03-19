# Pleroma: A lightweight social networking server
# Copyright © 2017-2021 Pleroma Authors <https://pleroma.social/>
# SPDX-License-Identifier: AGPL-3.0-only

defmodule Pleroma.Web.ActivityPub.ObjectValidators.AcceptRejectValidator do
  use Ecto.Schema

  alias Pleroma.Activity
  alias Pleroma.User

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    quote do
      unquote do
        import Elixir.Pleroma.Web.ActivityPub.ObjectValidators.CommonFields
        message_fields()
        activity_fields()
      end
    end

    field(:result, :string)
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  defp validate_data(cng) do
    cng
    |> validate_required([:type, :actor, :to, :cc, :object])
    |> validate_inclusion(:type, ["Accept", "Reject"])
    |> validate_actor_presence()
    |> validate_object_presence(allowed_types: ["Follow", "QuoteRequest"])
    |> validate_accept_reject_rights()
  end

  def cast_and_validate(data) do
    data
    |> maybe_fetch_object()
    |> cast_data
    |> validate_data
  end

  def validate_accept_reject_rights(cng) do
    with object_id when is_binary(object_id) <- get_field(cng, :object),
         %Activity{} = object_activity <- Activity.get_by_ap_id(object_id),
         true <- actor_has_rights?(get_field(cng, :actor), object_activity) do
      cng
    else
      _e ->
        cng
        |> add_error(:actor, "can't accept or reject the given activity")
    end
  end

  defp actor_has_rights?(actor, %Activity{data: %{"type" => "Follow", "object" => target}}) do
    actor == target
  end

  defp actor_has_rights?(actor, %Activity{data: %{"type" => "QuoteRequest", "object" => quoted_object_id}}) do
    with %Pleroma.Object{} = object <- Pleroma.Object.get_cached_by_ap_id(quoted_object_id) do
      (object.data["attributedTo"] || object.data["actor"]) == actor
    else
      _ -> false
    end
  end

  defp actor_has_rights?(_, _), do: false

  defp maybe_fetch_object(%{"object" => %{} = object} = activity) do
    # If we don't have an ID, we may have to fetch the object
    if Map.has_key?(object, "id") do
      # Do nothing
      activity
    else
      Map.put(activity, "object", fetch_transient_object(object))
    end
  end

  defp maybe_fetch_object(activity), do: activity

  defp fetch_transient_object(
         %{"actor" => actor, "object" => target, "type" => "Follow"} = object
       ) do
    with %User{} = actor <- User.get_cached_by_ap_id(actor),
         %User{local: true} = target <- User.get_cached_by_ap_id(target),
         %Activity{} = activity <- Activity.follow_activity(actor, target) do
      activity.data
    else
      _e ->
        object
    end
  end

  defp fetch_transient_object(
         %{"actor" => _actor, "object" => _quoted, "type" => "QuoteRequest"} = object
       ) do
    with %Activity{} = activity <- Activity.get_by_ap_id(object["id"]) do
      activity.data
    else
      _e -> object
    end
  end

  defp fetch_transient_object(_), do: {:error, "not a supported transient object"}
end
