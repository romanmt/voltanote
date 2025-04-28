defmodule Voltanote.Notes do
  @moduledoc """
  The Notes context.
  Provides a user-friendly API for working with notes.
  """

  alias Voltanote.Services.Notes.NotesService
  alias Voltanote.Supervisors.SessionSupervisor
  alias Voltanote.Schema.Note

  @doc """
  Creates a new note for a user.

  ## Examples

      iex> create_note(1, %{title: "My Note", content: "Content"})
      {:ok, %Note{}}
  """
  def create_note(user_id, attrs) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.create_note(user_id, attrs)
  end

  @doc """
  Gets a note by ID for a user.

  ## Examples

      iex> get_note(1, 123)
      {:ok, %Note{}}

      iex> get_note(1, 456)
      {:error, :not_found}
  """
  def get_note(user_id, note_id) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.get_note(user_id, note_id)
  end

  @doc """
  Gets a note by Zettel ID for a user.

  ## Examples

      iex> get_note_by_zettel(1, "202404281234")
      {:ok, %Note{}}

      iex> get_note_by_zettel(1, "nonexistent")
      {:error, :not_found}
  """
  def get_note_by_zettel(user_id, zettel_id) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.get_note_by_zettel(user_id, zettel_id)
  end

  @doc """
  Lists all notes for a user.

  ## Examples

      iex> list_notes(1)
      [%Note{}, ...]
  """
  def list_notes(user_id) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.list_notes(user_id)
  rescue
    # Handle any errors gracefully for the LiveView
    _error -> []
  end

  @doc """
  Updates a note for a user.

  ## Examples

      iex> update_note(1, 123, %{title: "Updated Title"})
      {:ok, %Note{}}

      iex> update_note(1, 456, %{title: "Updated Title"})
      {:error, :not_found}
  """
  def update_note(user_id, note_id, attrs) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.update_note(user_id, note_id, attrs)
  end

  @doc """
  Deletes a note for a user.

  ## Examples

      iex> delete_note(1, 123)
      :ok

      iex> delete_note(1, 456)
      {:error, :not_found}
  """
  def delete_note(user_id, note_id) do
    # First start the user session
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Then start or get the user's NotesService
    {:ok, _pid} = SessionSupervisor.get_or_start_notes_service(user_id)

    # Delegate to the NotesService
    NotesService.delete_note(user_id, note_id)
  end

  @doc """
  Forces synchronization of notes to the database.

  ## Examples

      iex> sync(1)
      :ok
  """
  def sync(user_id) do
    # First start the user session if needed
    {:ok, _pid} = SessionSupervisor.start_user_session(user_id)

    # Check if the user's NotesService exists
    case Registry.lookup(Voltanote.ServiceRegistry, {NotesService, user_id}) do
      [{_pid, _}] ->
        # Delegate to the NotesService
        NotesService.sync(user_id)
      [] ->
        # If no service exists, nothing to sync
        :ok
    end
  end

  @doc """
  Ends a user's session, which will trigger final synchronization.

  ## Examples

      iex> end_session(1)
      :ok
  """
  def end_session(user_id) do
    # Sync first to ensure all changes are persisted
    sync(user_id)

    # Stop the user session
    SessionSupervisor.stop_user_session(user_id)
  end
end
