# CONCERN INCLUDED IN TWO UNRELATED MODELS
# Because Gunslingers and Saloons both... drink?
module Drinkable
  extend ActiveSupport::Concern

  def favorite_drink
    "Whiskey" # hardcoded, included in two models, tested by zero specs
  end

  def drunk?
    rand < 0.3 # 30% chance, always
  end

  def order_drink(drink_name)
    # Does nothing. Has never done anything.
    # But removing it breaks a test somewhere (we think).
    true
  end
end
