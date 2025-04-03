defmodule Gale.Repo.Migrations.CreateFiltersForUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :filters, {:array, :string}, default: []
    end
  end
end
