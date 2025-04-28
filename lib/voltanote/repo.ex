defmodule Voltanote.Repo do
  use Ecto.Repo,
    otp_app: :voltanote,
    adapter: Ecto.Adapters.Postgres
end
