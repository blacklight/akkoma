defmodule Pleroma.Repo.Migrations.CreateQuoteAuthorizations do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:quote_authorizations, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:ap_id, :text, null: false)
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:quoted_ap_id, :text, null: false)
      add(:quoting_ap_id, :text, null: false)
      add(:data, :map, null: false)

      timestamps()
    end

    create_if_not_exists(unique_index(:quote_authorizations, [:ap_id]))
    create_if_not_exists(index(:quote_authorizations, [:user_id]))
    create_if_not_exists(index(:quote_authorizations, [:quoted_ap_id]))
  end
end
