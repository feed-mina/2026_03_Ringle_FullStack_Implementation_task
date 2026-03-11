class CreateUserMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :user_memberships do |t|
      t.integer :user_id, null: false
      t.references :membership, null: false, foreign_key: true
      t.datetime :started_at, null: false
      t.datetime :expires_at, null: false
      t.string :status, null: false, default: "active", limit: 20
      t.string :granted_by, null: false, default: "purchase", limit: 20

      t.timestamps
    end

    add_index :user_memberships, :user_id
    add_index :user_memberships, :expires_at
    add_index :user_memberships, [ :user_id, :status ]
  end
end
