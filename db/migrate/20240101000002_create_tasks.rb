class CreateTasks < ActiveRecord::Migration[7.1]
  def change
    create_table :tasks do |t|
      t.string :title, null: false
      t.text :description
      t.integer :priority, default: 1
      t.string :status, default: "todo"
      t.references :user, null: false, foreign_key: true
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
