# STI ABUSE
# "We need three types of bounty" "Just add a type column"
class Bounty < ApplicationRecord
  belongs_to :gunslinger
  belongs_to :posted_by, class_name: "Gunslinger"

  validates :amount, presence: true

  # default_scope — the gift that keeps on giving
  default_scope { where(status: "active") }

  enum status: { active: "active", claimed: "claimed", expired: "expired", cancelled: "cancelled" }

  after_create :update_wanted_level

  private

  def update_wanted_level
    # modifies another record from a callback
    new_level = gunslinger.bounties.unscoped.where(status: "active").sum(:amount) / 100
    gunslinger.update!(wanted_level: [new_level, 10].min)
  end
end

# STI children that add almost nothing
class DeadBounty < Bounty
  before_create { self.description = "#{gunslinger.name} — DEAD. #{description}" }
end

class AliveBounty < Bounty
  before_create { self.description = "#{gunslinger.name} — ALIVE ONLY. #{description}" }
end

class DeadOrAliveBounty < Bounty
  before_create { self.description = "#{gunslinger.name} — DEAD OR ALIVE. #{description}" }
end
