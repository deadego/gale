defmodule Gale.Repo.Migrations.CreateTokenOnUser do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :access_jwt, :text
      add :refresh_jwt, :text
    end
  end
end
