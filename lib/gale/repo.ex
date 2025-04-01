defmodule Gale.Repo do
  use Ecto.Repo,
    otp_app: :gale,
    adapter: Ecto.Adapters.Postgres
end
