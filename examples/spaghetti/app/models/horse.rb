# AMBIGUOUS OWNERSHIP + DEFAULT SCOPE
# "Which town does the horse belong to? The gunslinger's town? Or its own?"
# "Yes."
class Horse < ApplicationRecord
  belongs_to :gunslinger
  belongs_to :town, optional: true

  validates :name, presence: true

  # The default_scope that makes every query wrong
  default_scope { where(alive: true) }

  # Circular callback: Horse saves → Gunslinger saves → Town saves → ...
  after_save :sync_town_with_owner

  private

  def sync_town_with_owner
    if gunslinger&.town_id != town_id
      update_column(:town_id, gunslinger&.town_id)
    end
  end
end
