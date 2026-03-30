# THE JUNK DRAWER CONCERN
# "Let's extract shared logic into a concern" — famous last words
#
# Included in: Gunslinger, Town, Bounty, Duel
# Actually used by: maybe Gunslinger
module Calculatable
  extend ActiveSupport::Concern

  included do
    # adds a scope to every model that includes this, whether it makes sense or not
    scope :recent, -> { where("created_at > ?", 7.days.ago) }
    scope :by_name, -> { order(:name) }
  end

  def days_since_creation
    ((Time.current - created_at) / 1.day).round
  end

  def stale?
    days_since_creation > 30
  end

  # "We might need this somewhere"
  def to_summary
    attributes.map { |k, v| "#{k}: #{v}" }.join(", ")
  end

  # Generic "score" that means something different for every model
  def calculated_score
    if respond_to?(:reputation)
      reputation.to_f * 1.5
    elsif respond_to?(:amount)
      amount.to_f / 100
    elsif respond_to?(:population)
      population.to_f / lawlessness_rating.to_f rescue 0
    else
      0
    end
  end

  # "We'll make this configurable later"
  def display_name
    if respond_to?(:nickname) && nickname.present?
      "#{name} (#{nickname})"
    elsif respond_to?(:name)
      name
    else
      "Unknown"
    end
  end

  class_methods do
    def top_scorers(limit = 10)
      all.sort_by { |r| -r.calculated_score }.first(limit)
    end

    # loads ALL records into memory to count them
    def slow_count
      all.to_a.length
    end
  end
end
