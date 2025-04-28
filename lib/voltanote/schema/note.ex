defmodule Voltanote.Schema.Note do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  schema "notes" do
    field :title, :string
    field :content, :string
    field :user_id, :integer
    field :zettel_id, :string
    field :tags, {:array, :string}, default: []
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc """
  Creates a changeset for a note.
  """
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :content, :user_id, :zettel_id, :tags, :metadata])
    |> validate_required([:title, :content, :user_id])
    |> ensure_zettel_id()
  end

  @doc """
  Ensures that a zettel_id exists, generating one if needed.
  Uses timestamp-based ID in the format YYYYMMDDHHMM (year, month, day, hour, minute)
  """
  defp ensure_zettel_id(changeset) do
    case get_change(changeset, :zettel_id) do
      nil ->
        now = DateTime.utc_now()
        zettel_id = "#{now.year}#{pad(now.month)}#{pad(now.day)}#{pad(now.hour)}#{pad(now.minute)}"
        put_change(changeset, :zettel_id, zettel_id)
      _ ->
        changeset
    end
  end

  defp pad(number) when number < 10, do: "0#{number}"
  defp pad(number), do: "#{number}"
end
