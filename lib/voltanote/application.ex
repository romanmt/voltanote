defmodule Voltanote.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Voltanote.Repo,
      VoltanoteWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:voltanote, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Voltanote.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Voltanote.Finch},
      # Start a worker by calling: Voltanote.Worker.start_link(arg)
      # {Voltanote.Worker, arg},
      # Start to serve requests, typically the last entry
      VoltanoteWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Voltanote.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    VoltanoteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
