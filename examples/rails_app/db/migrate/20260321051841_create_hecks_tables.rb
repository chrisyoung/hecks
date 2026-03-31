class CreateHecksTables < ActiveRecord::Migration[7.2]
  def change
    create_table :pizzas, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :name
      t.string :description
      t.datetime :created_at
      t.datetime :updated_at
    end

    create_table :pizzas_toppings, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :pizza_id, limit: 36, null: false
      t.string :name
      t.integer :amount
    end

    add_foreign_key :pizzas_toppings, :pizzas

    create_table :orders, id: false do |t|
      t.string :id, limit: 36, primary_key: true
      t.string :pizza_id, limit: 36
      t.integer :quantity
      t.string :status
      t.datetime :created_at
      t.datetime :updated_at
    end
  end
end
