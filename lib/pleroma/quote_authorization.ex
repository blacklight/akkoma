defmodule Pleroma.QuoteAuthorization do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Pleroma.Repo
  alias Pleroma.User

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "quote_authorizations" do
    field(:ap_id, :string)
    field(:quoted_ap_id, :string)
    field(:quoting_ap_id, :string)
    field(:data, :map)

    belongs_to(:user, User, type: FlakeId.Ecto.CompatType)

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:ap_id, :user_id, :quoted_ap_id, :quoting_ap_id, :data])
    |> validate_required([:ap_id, :user_id, :quoted_ap_id, :quoting_ap_id, :data])
    |> unique_constraint(:ap_id)
  end

  def get_by_ap_id(ap_id) do
    Repo.get_by(__MODULE__, ap_id: ap_id)
  end

  def get_by_quoted_and_quoting(quoted_ap_id, quoting_ap_id) do
    __MODULE__
    |> where([qa], qa.quoted_ap_id == ^quoted_ap_id and qa.quoting_ap_id == ^quoting_ap_id)
    |> Repo.one()
  end

  def create(params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert()
  end

  def delete_by_ap_id(ap_id) do
    case get_by_ap_id(ap_id) do
      nil -> {:error, :not_found}
      qa -> Repo.delete(qa)
    end
  end
end
