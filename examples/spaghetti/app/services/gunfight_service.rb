# THE SERVICE OBJECT THAT WRAPS .create WITH EXTRA STEPS
# "We should use the service object pattern" — a blog post from 2017
class GunfightService
  def initialize(challenger:, opponent:, town:)
    @challenger = challenger
    @opponent = opponent
    @town = town
  end

  def call
    return { success: false, error: "Can't duel yourself" } if @challenger.id == @opponent.id
    return { success: false, error: "Dead men don't duel" } unless @challenger.alive? && @opponent.alive?
    return { success: false, error: "Not in the same town" } if @challenger.town_id != @opponent.town_id

    # All this service does is call .create! with extra validation
    # that should be on the model
    duel = Duel.create!(
      challenger: @challenger,
      opponent: @opponent,
      town: @town,
      dramatic_pause_seconds: rand(1.0..5.0).round(1)
    )

    { success: true, duel: duel }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: e.message }
  rescue => e
    # Catch everything. Log nothing.
    { success: false, error: "Something went wrong" }
  end
end
