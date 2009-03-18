class CreateMultipleChoices < ActiveRecord::Migration
  def self.up
    create_table :multiple_choices do |t|
      t.timestamps
      t.string      :name
      t.string      :description
      t.integer     :user_id
      t.column      :uuid, :string, :limit => 36
      t.string      :prompt
      t.string      :default_response
    end
  end

  def self.down
    drop_table :multiple_choices
  end
end
