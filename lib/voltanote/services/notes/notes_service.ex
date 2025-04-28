defmodule Voltanote.Services.Notes.NotesService do
  @moduledoc """
  Service for managing notes in memory with async database persistence.
  This service is started dynamically per user session.
  """
  use GenServer
  require Logger
  import Ecto.Query

  alias Voltanote.Schema.Note
  alias Voltanote.Repo

  # Client API

  @doc """
  Starts a new notes service for a user.
  """
  def start_link(user_id) when is_integer(user_id) do
    GenServer.start_link(__MODULE__, %{user_id: user_id}, name: via_tuple(user_id))
  end

  @doc """
  Creates a new note in memory and schedules persistence.
  """
  def create_note(user_id, attrs) do
    GenServer.call(via_tuple(user_id), {:create_note, attrs})
  end

  @doc """
  Gets a note by its ID.
  """
  def get_note(user_id, note_id) do
    GenServer.call(via_tuple(user_id), {:get_note, note_id})
  end

  @doc """
  Gets a note by its zettel_id.
  """
  def get_note_by_zettel(user_id, zettel_id) do
    GenServer.call(via_tuple(user_id), {:get_note_by_zettel, zettel_id})
  end

  @doc """
  Lists all notes for a user.
  """
  def list_notes(user_id) do
    GenServer.call(via_tuple(user_id), :list_notes)
  end

  @doc """
  Updates a note.
  """
  def update_note(user_id, note_id, attrs) do
    GenServer.call(via_tuple(user_id), {:update_note, note_id, attrs})
  end

  @doc """
  Deletes a note.
  """
  def delete_note(user_id, note_id) do
    GenServer.call(via_tuple(user_id), {:delete_note, note_id})
  end

  @doc """
  Forces a sync to the database.
  """
  def sync(user_id) do
    GenServer.call(via_tuple(user_id), :sync)
  end

  # Server Callbacks

  @impl true
  def init(%{user_id: user_id}) do
    Logger.info("Starting NotesService for user #{user_id}")
    # Load notes from database
    notes = load_notes_from_db(user_id)

    # Initialize ETS table for this user
    :ets.new(table_name(user_id), [:set, :protected, :named_table])

    # Populate ETS table
    Enum.each(notes, fn note ->
      :ets.insert(table_name(user_id), {note.id, note})
    end)

    # Schedule periodic persistence
    schedule_persistence()

    {:ok, %{
      user_id: user_id,
      dirty: false,
      notes_count: length(notes)
    }}
  end

  @impl true
  def handle_call({:create_note, attrs}, _from, %{user_id: user_id} = state) do
    # Convert string keys to atoms to handle form submissions
    attrs_with_atoms = for {key, val} <- attrs, into: %{} do
      if is_binary(key), do: {String.to_atom(key), val}, else: {key, val}
    end

    # Create a changeset with the user_id included
    attrs_with_user = Map.put(attrs_with_atoms, :user_id, user_id)
    changeset = Note.changeset(%Note{}, attrs_with_user)

    case Repo.insert(changeset) do
      {:ok, note} ->
        # Store in ETS with the database ID
        :ets.insert(table_name(user_id), {note.id, note})

        {:reply, {:ok, note}, %{state | dirty: true, notes_count: state.notes_count + 1}}

      {:error, changeset} ->
        {:reply, {:error, changeset}, state}
    end
  end

  @impl true
  def handle_call({:get_note, note_id}, _from, %{user_id: user_id} = state) do
    case :ets.lookup(table_name(user_id), note_id) do
      [{^note_id, note}] ->
        {:reply, {:ok, note}, state}
      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:get_note_by_zettel, zettel_id}, _from, %{user_id: user_id} = state) do
    # This is inefficient in ETS, but for demo purposes it's ok
    # In a production app, you might want to maintain a separate ETS table for zettel_id lookup
    result = :ets.tab2list(table_name(user_id))
             |> Enum.find(fn {_id, note} -> note.zettel_id == zettel_id end)

    case result do
      {_id, note} -> {:reply, {:ok, note}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:list_notes, _from, %{user_id: user_id} = state) do
    notes = :ets.tab2list(table_name(user_id))
            |> Enum.map(fn {_id, note} -> note end)
            |> Enum.sort_by(fn note -> note.inserted_at end, {:desc, DateTime})

    {:reply, notes, state}
  end

  @impl true
  def handle_call({:update_note, note_id, attrs}, _from, %{user_id: user_id} = state) do
    case :ets.lookup(table_name(user_id), note_id) do
      [{^note_id, note}] ->
        # Convert string keys to atoms to handle form submissions
        attrs_with_atoms = for {key, val} <- attrs, into: %{} do
          if is_binary(key), do: {String.to_atom(key), val}, else: {key, val}
        end

        changeset = Note.changeset(note, attrs_with_atoms)

        case Repo.update(changeset) do
          {:ok, updated_note} ->
            # Update ETS with the updated note
            :ets.insert(table_name(user_id), {note_id, updated_note})
            {:reply, {:ok, updated_note}, %{state | dirty: true}}

          {:error, changeset} ->
            {:reply, {:error, changeset}, state}
        end

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:delete_note, note_id}, _from, %{user_id: user_id} = state) do
    case :ets.lookup(table_name(user_id), note_id) do
      [{^note_id, note}] ->
        # Remove from ETS
        :ets.delete(table_name(user_id), note_id)

        # Delete from database
        case Repo.delete(note) do
          {:ok, _} ->
            {:reply, :ok, %{state | dirty: true, notes_count: state.notes_count - 1}}

          {:error, reason} ->
            # If DB delete fails, re-insert into ETS and return error
            :ets.insert(table_name(user_id), {note_id, note})
            {:reply, {:error, reason}, state}
        end

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:sync, _from, state) do
    result = persist_to_database(state)
    new_state = %{state | dirty: false}
    {:reply, result, new_state}
  end

  @impl true
  def handle_info(:persist, state) do
    new_state = if state.dirty do
      case persist_to_database(state) do
        :ok -> %{state | dirty: false}
        _error -> state
      end
    else
      state
    end

    schedule_persistence()
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("Terminating NotesService for user #{state.user_id}")
    # Final sync to ensure all changes are persisted
    if state.dirty do
      persist_to_database(state)
    end
    :ok
  end

  # Private functions

  defp via_tuple(user_id) do
    {:via, Registry, {Voltanote.ServiceRegistry, {__MODULE__, user_id}}}
  end

  defp table_name(user_id) do
    :"notes_#{user_id}"
  end

  defp load_notes_from_db(user_id) do
    Repo.all(
      from note in Note,
      where: note.user_id == ^user_id,
      order_by: [desc: note.inserted_at]
    )
  end

  defp persist_to_database(%{user_id: user_id}) do
    Logger.info("Persisting notes to database for user #{user_id}")

    # Start a DB transaction
    Repo.transaction(fn ->
      # Get all notes from ETS
      ets_notes = :ets.tab2list(table_name(user_id))
                   |> Enum.map(fn {_id, note} -> note end)

      # Get existing DB notes for this user
      db_notes = load_notes_from_db(user_id)

      # Map existing notes by zettel_id for easy lookup
      db_notes_by_zettel_id = Enum.reduce(db_notes, %{}, fn note, acc ->
        Map.put(acc, note.zettel_id, note)
      end)

      # Find notes to insert or update
      new_ets_notes = Enum.map(ets_notes, fn note ->
        case Map.get(db_notes_by_zettel_id, note.zettel_id) do
          nil ->
            # New note, need to insert
            # Create changeset without the ID to let the database generate it
            attrs = Map.from_struct(note) |> Map.delete(:id)

            inserted_note = %Note{}
                           |> Note.changeset(attrs)
                           |> Repo.insert!()

            # Replace the temp ID with the new database ID
            :ets.delete(table_name(user_id), note.id)
            :ets.insert(table_name(user_id), {inserted_note.id, inserted_note})

            inserted_note

          existing ->
            # Update existing note, using the database ID
            updated_attrs = Map.from_struct(note)
                            |> Map.delete(:id)
                            |> Map.put(:id, existing.id)

            updated_note = existing
                          |> Note.changeset(updated_attrs)
                          |> Repo.update!()

            # If the note had a temporary ID, update it in ETS
            if note.id != existing.id do
              :ets.delete(table_name(user_id), note.id)
              :ets.insert(table_name(user_id), {updated_note.id, updated_note})
            else
              :ets.insert(table_name(user_id), {updated_note.id, updated_note})
            end

            updated_note
        end
      end)

      # Find notes to delete (in DB but not in ETS)
      ets_zettel_ids = Enum.map(ets_notes, & &1.zettel_id) |> MapSet.new()

      db_notes
      |> Enum.filter(fn note -> !MapSet.member?(ets_zettel_ids, note.zettel_id) end)
      |> Enum.each(fn note -> Repo.delete!(note) end)
    end)

    :ok
  rescue
    error ->
      Logger.error("Error persisting notes to database: #{inspect(error)}")
      {:error, error}
  end

  defp schedule_persistence do
    # Schedule persistence after 1 minute
    # In a real app, you might want to make this configurable
    Process.send_after(self(), :persist, 60_000)
  end
end
