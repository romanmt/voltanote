defmodule VoltanoteWeb.NotesLive do
  use VoltanoteWeb, :live_view

  alias Voltanote.Notes
  alias Voltanote.Schema.Note

  @impl true
  def mount(_params, _session, socket) do
    # For now, we'll use a hardcoded user_id of 1
    # In a real app, this would come from authentication
    user_id = 1

    if connected?(socket) do
      # Load notes when the LiveView is connected
      # This might return an empty list if there's an error
      notes = Notes.list_notes(user_id)

      {:ok, assign(socket,
        notes: notes,
        user_id: user_id,
        loading: false,
        selected_note: nil,
        page_title: "Notes"
      )}
    else
      # Initial render shows loading state
      {:ok, assign(socket,
        notes: [],
        user_id: user_id,
        loading: true,
        selected_note: nil,
        page_title: "Notes"
      )}
    end
  end

  @impl true
  def handle_params(%{"id" => note_id}, _uri, socket) do
    # When a note ID is provided in the URL, load that note
    case Notes.get_note(socket.assigns.user_id, String.to_integer(note_id)) do
      {:ok, note} ->
        {:noreply, assign(socket, selected_note: note, page_title: note.title)}
      {:error, _} ->
        # If note doesn't exist, redirect to notes index
        {:noreply, push_navigate(socket, to: ~p"/notes")}
    end
  rescue
    # Handle any errors gracefully
    _error -> {:noreply, push_navigate(socket, to: ~p"/notes")}
  end

  def handle_params(%{"zettel_id" => zettel_id}, _uri, socket) do
    # Look up note by zettel_id
    case Notes.get_note_by_zettel(socket.assigns.user_id, zettel_id) do
      {:ok, note} ->
        {:noreply, assign(socket, selected_note: note, page_title: note.title)}
      {:error, _} ->
        {:noreply, push_navigate(socket, to: ~p"/notes")}
    end
  rescue
    # Handle any errors gracefully
    _error -> {:noreply, push_navigate(socket, to: ~p"/notes")}
  end

  def handle_params(_params, _uri, socket) do
    # Default case - notes index
    {:noreply, assign(socket, selected_note: nil, page_title: "Notes")}
  end

  @impl true
  def handle_event("new_note", _params, socket) do
    # Clear selected note and show new note form
    {:noreply, assign(socket, selected_note: %Note{}, page_title: "New Note")}
  end

  # Handle save_note with a note map parameter for new note
  @impl true
  def handle_event("save_note", %{"note" => note_params}, %{assigns: %{selected_note: %Note{id: nil}}} = socket) do
    # Create a new note with params from note map
    create_new_note(socket, note_params)
  end

  # Handle direct form parameters for new note
  @impl true
  def handle_event("save_note", params, %{assigns: %{selected_note: %Note{id: nil}}} = socket) when is_map(params) do
    # Create a new note with direct params
    create_new_note(socket, params)
  end

  # Handle save_note with a note map parameter for existing note
  @impl true
  def handle_event("save_note", %{"note" => note_params}, socket) do
    # Update existing note with params from note map
    update_existing_note(socket, note_params)
  end

  # Handle direct form parameters for existing note
  @impl true
  def handle_event("save_note", params, socket) when is_map(params) do
    # Update existing note with direct params
    update_existing_note(socket, params)
  end

  @impl true
  def handle_event("delete_note", %{"id" => note_id}, socket) do
    note_id = String.to_integer(note_id)

    case Notes.delete_note(socket.assigns.user_id, note_id) do
      :ok ->
        # Remove note from the list
        updated_notes = Enum.reject(socket.assigns.notes, fn note -> note.id == note_id end)

        {:noreply, socket
          |> put_flash(:info, "Note deleted successfully!")
          |> assign(notes: updated_notes, selected_note: nil)
          |> push_patch(to: ~p"/notes")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Error deleting note")}
    end
  rescue
    # Handle any errors gracefully
    error ->
      {:noreply, put_flash(socket, :error, "Error deleting note: #{inspect error}")}
  end

  @impl true
  def handle_event("select_note", %{"id" => note_id}, socket) do
    # Navigate to the selected note
    {:noreply, push_patch(socket, to: ~p"/notes/#{note_id}")}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    # Cancel editing and go back to notes list
    {:noreply, push_patch(socket, to: ~p"/notes")}
  end

  # Private helper functions

  defp create_new_note(socket, params) do
    case Notes.create_note(socket.assigns.user_id, params) do
      {:ok, note} ->
        notes = [note | socket.assigns.notes]
        {:noreply, socket
          |> put_flash(:info, "Note created successfully!")
          |> assign(notes: notes, selected_note: note)
          |> push_patch(to: ~p"/notes/#{note.id}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Error creating note: #{inspect changeset.errors}")}
    end
  rescue
    # Handle any errors gracefully
    error ->
      {:noreply, put_flash(socket, :error, "Error creating note: #{inspect error}")}
  end

  defp update_existing_note(socket, params) do
    note_id = socket.assigns.selected_note.id

    case Notes.update_note(socket.assigns.user_id, note_id, params) do
      {:ok, updated_note} ->
        # Update the note in the list
        updated_notes = Enum.map(socket.assigns.notes, fn note ->
          if note.id == note_id, do: updated_note, else: note
        end)

        {:noreply, socket
          |> put_flash(:info, "Note updated successfully!")
          |> assign(notes: updated_notes, selected_note: updated_note)}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Error updating note: #{inspect changeset.errors}")}
    end
  rescue
    # Handle any errors gracefully
    error ->
      {:noreply, put_flash(socket, :error, "Error updating note: #{inspect error}")}
  end
end
