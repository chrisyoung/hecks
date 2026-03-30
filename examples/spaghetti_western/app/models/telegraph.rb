# THE SECOND DATABASE
# "We need an audit trail" "Just use a second SQLite"
class Telegraph < ApplicationRecord
  # In a real app this would be:
  # establish_connection(
  #   adapter: "sqlite3",
  #   database: "db/telegraph.sqlite3"
  # )
  #
  # Because nothing says "audit trail" like a separate
  # SQLite file that nobody can join against.

  belongs_to :town

  validates :message, presence: true
  validates :event_type, presence: true

  # Raw SQL for "performance"
  def self.unread_for_town(town_name)
    where("town_id IN (SELECT id FROM towns WHERE name = '#{town_name}') AND read = 0")
  end

  # Updates town on create — another callback cascade
  after_create :bump_town_activity

  private

  def bump_town_activity
    town&.recalculate_lawlessness!
  end
end
