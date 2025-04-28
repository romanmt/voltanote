defmodule VoltanoteWeb.NotesLiveTest do
  use VoltanoteWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "NotesLive" do
    test "displays empty state when no notes exist", %{conn: conn} do
      # You'd want to stub the Notes module in a real application
      # to return an empty list of notes for testing

      # For this example, we just assert the route works
      # and we'd see the empty state message
      {:ok, _view, html} = live(conn, ~p"/notes")

      assert html =~ "My Notes"
      assert html =~ "No notes yet" # This would be visible in the empty state
    end

    test "can navigate to create new note form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notes")

      view |> element("button", "Create New Note") |> render_click()

      # Assert that we're now showing the new note form
      assert has_element?(view, "form")
      assert has_element?(view, "button", "Create Note")
    end

    # In a real application with proper test setup,
    # we would also test:
    # - Creating a new note
    # - Viewing an existing note
    # - Editing a note
    # - Deleting a note
    # - Validation errors

    # Example of what a more complete test might look like:
    #
    # test "can create a new note", %{conn: conn} do
    #   {:ok, view, _html} = live(conn, ~p"/notes")
    #
    #   # Click the new note button
    #   view
    #     |> element("button", "Create New Note")
    #     |> render_click()
    #
    #   # Fill out and submit the form
    #   view
    #     |> form("form", %{
    #       "note" => %{
    #         "title" => "Test Note",
    #         "content" => "This is a test note"
    #       }
    #     })
    #     |> render_submit()
    #
    #   # Flash message should confirm success
    #   assert has_element?(view, ".flash", "Note created successfully")
    #
    #   # New note should be visible in the list
    #   assert has_element?(view, "li", "Test Note")
    # end
  end
end
