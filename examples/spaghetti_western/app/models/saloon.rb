# EVAL IN PRODUCTION
class Saloon < ApplicationRecord
  include Drinkable

  belongs_to :town
  has_many :fights, class_name: "Duel", foreign_key: :town_id # wrong FK, always returns wrong data

  validates :name, presence: true

  # store JSON, parse with eval, what could go wrong
  def menu
    return {} unless drink_prices
    eval(drink_prices) rescue {} # rubocop:disable Security/Eval
  end

  def cheapest_drink
    menu.min_by { |_, price| price }&.first
  end

  # updates trouble_rating by counting fights in the TOWN, not the SALOON
  # (because the FK is wrong)
  after_save :recalculate_trouble

  private

  def recalculate_trouble
    fight_count = Duel.where(town_id: town_id).count
    update_column(:trouble_rating, fight_count * 0.5)
    town.recalculate_lawlessness! # and cascade the N+1 again
  end
end
