# ALL BUSINESS LOGIC LIVES HERE
# "We'll refactor this later" — 2019
class Duel < ApplicationRecord
  belongs_to :challenger, class_name: "Gunslinger"
  belongs_to :opponent, class_name: "Gunslinger"
  belongs_to :town
  belongs_to :winner, class_name: "Gunslinger", optional: true

  validates :dramatic_pause_seconds, presence: true

  after_create :simulate!

  include AASM
  aasm column: :status do
    state :scheduled, initial: true
    state :in_progress
    state :finished
    state :cancelled

    event :begin do
      transitions from: :scheduled, to: :in_progress
    end

    event :finish do
      transitions from: :in_progress, to: :finished
    end

    event :cancel do
      transitions from: :scheduled, to: :cancelled
    end
  end

  # 80 lines of nested if/else in a model method, called from a callback
  def simulate!
    return if status == "cancelled"

    update!(status: "in_progress")

    # dramatic narration built with string concatenation
    narration = ""
    narration += "The sun beats down on #{town.name}. "
    narration += "#{challenger.name} faces #{opponent.name}. "

    if challenger.accuracy.nil? || opponent.accuracy.nil?
      narration += "Someone forgot their guns. "
      update!(status: "cancelled", narration: narration)
      return
    end

    # the "algorithm"
    challenger_roll = rand * challenger.accuracy
    opponent_roll = rand * opponent.accuracy

    if challenger.preferred_weapon == "dual_revolvers"
      challenger_roll *= 1.2
    end
    if opponent.preferred_weapon == "dual_revolvers"
      opponent_roll *= 1.2
    end

    if challenger_roll > opponent_roll
      the_winner = challenger
      the_loser = opponent
    elsif opponent_roll > challenger_roll
      the_winner = opponent
      the_loser = challenger
    else
      narration += "A draw! Both walk away. "
      update!(status: "finished", narration: narration)
      return
    end

    narration += "#{the_winner.name} draws first! "

    # 30% chance of death, calculated in the model, modifying other records
    if rand < 0.3
      the_loser.update!(alive: false)
      narration += "#{the_loser.name} falls in the dust. "
      the_winner.update!(kills: the_winner.kills + 1)
    else
      narration += "#{the_loser.name} staggers away, wounded. "
    end

    update!(winner_id: the_winner.id, status: "finished", narration: narration)

    # callback that triggers another model's callbacks
    Telegraph.create!(
      sender: "Witness",
      recipient: "Town Crier",
      message: "DUEL: #{the_winner.name} defeated #{the_loser.name} in #{town.name}",
      event_type: "duel_result",
      town: town,
      sent_at: Time.current
    )
  end
end
