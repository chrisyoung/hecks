# THE N+1 FACTORY
class Town < ApplicationRecord
  has_many :gunslingers
  has_many :duels
  has_many :saloons
  has_many :horses
  has_many :telegraphs

  validates :name, presence: true
  validates :population, presence: true

  # This method is called from 4 different callbacks on other models
  def recalculate_lawlessness!
    # N+1 query bonanza
    total_wanted = gunslingers.select { |g| g.wanted_level > 0 }.count
    total_kills = gunslingers.map(&:kills).sum
    recent_duels = duels.where("created_at > ?", 30.days.ago).count
    dead_in_town = gunslingers.where(alive: false).count
    saloon_trouble = saloons.map(&:trouble_rating).sum

    score = (total_wanted * 2.0 + total_kills * 0.5 + recent_duels * 1.5 + dead_in_town * 3.0 + saloon_trouble) / [population, 1].max
    update!(lawlessness_rating: score.round(2))

    # update sheriff status based on lawlessness, triggering more saves
    if lawlessness_rating > 8.0 && has_sheriff
      update!(has_sheriff: false) # sheriff fled
    end
  end
end
