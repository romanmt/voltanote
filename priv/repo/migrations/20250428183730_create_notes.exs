defmodule Voltanote.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def up do
    create table(:notes) do
      add :title, :string
      add :content, :text
      add :user_id, :integer  # For future user authentication
      add :zettel_id, :string  # Unique ID for Zettelkasten implementation
      add :tags, {:array, :string}, default: []
      add :metadata, :map, default: %{}  # For extensible metadata

      timestamps()
    end

    # Create indexes for performance
    create index(:notes, [:user_id])
    create index(:notes, [:zettel_id])
    create index(:notes, [:tags])
    create index(:notes, ["inserted_at DESC"])
  end

  def down do
    # Drop indexes first
    drop index(:notes, [:user_id])
    drop index(:notes, [:zettel_id])
    drop index(:notes, [:tags])
    drop index(:notes, ["inserted_at DESC"])

    # Then drop the table
    drop table(:notes)
  end
end
