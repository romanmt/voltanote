defmodule Voltanote.Supervisors.SessionSupervisor do
  @moduledoc """
  Supervisor for user sessions and their associated services.
  """
  use DynamicSupervisor
  require Logger

  alias Voltanote.Services.Notes.NotesService

  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new user session.
  """
  def start_user_session(user_id) do
    case DynamicSupervisor.start_child(__MODULE__, {Voltanote.Supervisors.UserSessionSupervisor, user_id}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      error -> error
    end
  end

  @doc """
  Stops a user session.
  """
  def stop_user_session(user_id) do
    case Registry.lookup(Voltanote.SupervisorRegistry, {:user_session, user_id}) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Gets or starts the notes service for a user.
  """
  def get_or_start_notes_service(user_id) do
    Voltanote.Supervisors.UserSessionSupervisor.get_or_start_notes_service(user_id)
  end
end

defmodule Voltanote.Supervisors.UserSessionSupervisor do
  @moduledoc """
  Supervisor for a specific user session and its services.
  """
  use Supervisor
  require Logger

  alias Voltanote.Services.Notes.NotesService

  def start_link(user_id) do
    Supervisor.start_link(__MODULE__, user_id, name: via_tuple(user_id))
  end

  @impl true
  def init(user_id) do
    Logger.info("Starting user session for user #{user_id}")

    children = [
      # Define services that should be started with the user session
      # The NotesService is started on-demand, not automatically
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def get_or_start_notes_service(user_id) do
    # Try to find existing NotesService
    case Registry.lookup(Voltanote.ServiceRegistry, {NotesService, user_id}) do
      [{pid, _}] ->
        {:ok, pid}
      [] ->
        # Start a new NotesService if not found
        case Supervisor.start_child(via_tuple(user_id), {NotesService, user_id}) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          error -> error
        end
    end
  end

  defp via_tuple(user_id) do
    {:via, Registry, {Voltanote.SupervisorRegistry, {:user_session, user_id}}}
  end
end
