# THE GOD OBJECT
# "It started as a simple model" — every Rails dev ever
class Gunslinger < ApplicationRecord
  include Calculatable
  include Drinkable

  belongs_to :town, optional: true
  has_many :duels_as_challenger, class_name: "Duel", foreign_key: :challenger_id
  has_many :duels_as_opponent, class_name: "Duel", foreign_key: :opponent_id
  has_many :bounties
  has_many :horses
  has_many :posted_bounties, class_name: "Bounty", foreign_key: :posted_by_id

  validates :name, presence: true
  validates :accuracy, presence: true

  # 15 callbacks, as God intended
  before_validation :calculate_reputation
  before_save :check_if_wanted
  before_save :update_kill_streak
  after_save :notify_bounty_hunters
  after_save :update_town_lawlessness
  after_create :assign_starter_horse
  after_update :check_alive_status
  after_update :recalculate_everything

  scope :alive, -> { where(alive: true) }
  scope :wanted, -> { where("wanted_level > ?", 0) }
  scope :legendary, -> { where("reputation > ?", 100) }

  # Business logic that queries the DB from a callback
  def calculate_reputation
    return unless persisted?
    wins = Duel.where(winner_id: id).count
    losses = Duel.where("(challenger_id = ? OR opponent_id = ?) AND winner_id != ? AND winner_id IS NOT NULL", id, id, id).count
    self.reputation = (wins * 10) - (losses * 5) + (kills * 3)
  end

  # SQL injection waiting to happen
  def self.find_rivals(gunslinger_name)
    where("reputation > (SELECT reputation FROM gunslingers WHERE name = '#{gunslinger_name}')")
  end

  # N+1 extravaganza
  def all_duels
    (duels_as_challenger + duels_as_opponent).sort_by(&:created_at)
  end

  def win_rate
    total = all_duels.count
    return 0.0 if total == 0
    wins = all_duels.select { |d| d.winner_id == id }.count
    (wins.to_f / total * 100).round(1)
  end

  # Class variable. Because why not.
  @@total_deaths_this_session = 0

  def self.total_deaths
    @@total_deaths_this_session
  end

  private

  def check_if_wanted
    if kills > 3 && wanted_level == 0
      self.wanted_level = 1
    end
  end

  def update_kill_streak
    # reads from DB in a before_save
    self.kills = Duel.where(winner_id: id).where.not(winner_id: nil).count
  end

  def notify_bounty_hunters
    return unless wanted_level_previously_changed? && wanted_level > 0
    # In a real app this would send emails from a callback
    # Telegraph.create!(sender: "Sheriff", recipient: "ALL", message: "WANTED: #{name}", event_type: "bounty_alert")
    Town.all.each { |t| t.update!(lawlessness_rating: t.lawlessness_rating + 0.1) }
  end

  def update_town_lawlessness
    town&.recalculate_lawlessness! if saved_change_to_reputation?
  end

  def assign_starter_horse
    Horse.create!(name: "Old #{name}'s Mare", breed: "Mustang", speed: 5, gunslinger: self, town: town)
  end

  def check_alive_status
    if saved_change_to_alive? && !alive
      @@total_deaths_this_session += 1
      horses.update_all(alive: false) # kill the horses too, obviously
    end
  end

  def recalculate_everything
    # just recalculate everything on every save, what could go wrong
    town&.recalculate_lawlessness!
    bounties.where(status: "active").each { |b| b.update!(amount: b.amount + reputation) }
  end
end
