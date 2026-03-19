defmodule Pleroma.Web.ActivityPub.ObjectValidators.QuoteRequestValidator do
  use Ecto.Schema

  alias Pleroma.EctoType.ActivityPub.ObjectValidators
  alias Pleroma.Object
  alias Pleroma.User

  import Ecto.Changeset
  import Pleroma.Web.ActivityPub.ObjectValidators.CommonValidations

  @primary_key false

  embedded_schema do
    field(:id, ObjectValidators.ObjectID, primary_key: true)
    field(:type, :string)
    field(:actor, ObjectValidators.ObjectID)
    field(:object, ObjectValidators.ObjectID)
    field(:instrument, :string)
    field(:to, ObjectValidators.Recipients, default: [])
    field(:cc, ObjectValidators.Recipients, default: [])
  end

  def cast_data(data) do
    %__MODULE__{}
    |> cast(data, __schema__(:fields))
  end

  defp validate_data(cng) do
    cng
    |> validate_required([:id, :type, :actor, :object])
    |> validate_inclusion(:type, ["QuoteRequest"])
    |> validate_actor_presence()
    |> validate_quoted_object_is_local()
  end

  def cast_and_validate(data) do
    data
    |> maybe_extract_instrument()
    |> cast_data()
    |> validate_data()
  end

  defp validate_quoted_object_is_local(cng) do
    with object_id when is_binary(object_id) <- get_field(cng, :object),
         %Object{} = object <- Object.get_cached_by_ap_id(object_id),
         %User{local: true} <- User.get_cached_by_ap_id(object.data["attributedTo"] || object.data["actor"]) do
      cng
    else
      _ ->
        cng
        |> add_error(:object, "quoted object is not local or does not exist")
    end
  end

  defp maybe_extract_instrument(%{"instrument" => %{"id" => id}} = data) when is_binary(id) do
    Map.put(data, "instrument", id)
  end

  defp maybe_extract_instrument(%{"instrument" => instrument} = data) when is_binary(instrument) do
    data
  end

  defp maybe_extract_instrument(data), do: data
end
