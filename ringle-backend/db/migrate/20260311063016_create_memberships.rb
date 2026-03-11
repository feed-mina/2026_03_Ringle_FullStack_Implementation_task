class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.string :name, null: false, limit: 100
      t.boolean :can_learn, null: false, default: false
      t.boolean :can_converse, null: false, default: false
      t.boolean :can_analyze, null: false, default: false
      t.integer :duration_days, null: false
      t.integer :price_cents, null: false, default: 0
      t.text :description

      t.timestamps
    end

    add_index :memberships, :name, unique: true
  end
end
