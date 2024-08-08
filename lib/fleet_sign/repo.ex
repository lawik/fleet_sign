defmodule FleetSign.Repo do
  use Ecto.Repo,
    otp_app: :fleet_sign,
    adapter: Ecto.Adapters.Postgres
end
