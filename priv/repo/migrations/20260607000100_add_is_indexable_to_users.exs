defmodule Pleroma.Repo.Migrations.AddIsIndexableToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:is_indexable, :boolean, default: true, null: false)
    end
  end
end
