ActiveRecord::Schema.define(version: 2026_03_29_000000) do
  enable_extension "plpgsql"

  create_table "gunslingers", force: :cascade do |t|
    t.string "name"
    t.string "nickname"
    t.integer "reputation", default: 0
    t.float "accuracy"
    t.boolean "alive", default: true
    t.integer "wanted_level", default: 0
    t.integer "kills", default: 0
    t.string "preferred_weapon"
    t.references "town", foreign_key: true
    t.timestamps
  end

  create_table "duels", force: :cascade do |t|
    t.references "challenger", foreign_key: { to_table: :gunslingers }
    t.references "opponent", foreign_key: { to_table: :gunslingers }
    t.references "town", foreign_key: true
    t.references "winner", foreign_key: { to_table: :gunslingers }
    t.string "status"
    t.text "narration"
    t.float "dramatic_pause_seconds"
    t.timestamps
  end

  create_table "towns", force: :cascade do |t|
    t.string "name"
    t.integer "population"
    t.float "lawlessness_rating", default: 0.0
    t.boolean "has_sheriff", default: false
    t.string "region"
    t.timestamps
  end

  create_table "bounties", force: :cascade do |t|
    t.string "type"
    t.references "gunslinger", foreign_key: true
    t.references "posted_by", foreign_key: { to_table: :gunslingers }
    t.integer "amount"
    t.string "status"
    t.text "description"
    t.string "last_seen_location"
    t.timestamps
  end

  create_table "saloons", force: :cascade do |t|
    t.string "name"
    t.references "town", foreign_key: true
    t.json "drink_prices"
    t.integer "capacity"
    t.float "trouble_rating", default: 0.0
    t.timestamps
  end

  create_table "horses", force: :cascade do |t|
    t.string "name"
    t.string "breed"
    t.integer "speed"
    t.boolean "alive", default: true
    t.references "gunslinger", foreign_key: true
    t.references "town", foreign_key: true
    t.timestamps
  end

  create_table "telegraphs", force: :cascade do |t|
    t.string "sender"
    t.string "recipient"
    t.text "message"
    t.string "event_type"
    t.references "town", foreign_key: true
    t.datetime "sent_at"
    t.boolean "read", default: false
    t.timestamps
  end

  create_table "schema_migrations", force: :cascade do |t|
    t.string "version"
  end

  create_table "ar_internal_metadata", force: :cascade do |t|
    t.string "key"
    t.string "value"
  end
end
