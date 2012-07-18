class AddStateToUsers < ActiveRecord::Migration
  def change
    add_column :users, :state, :string, :default => "passive", :null => false
    add_column :users, :uuid, :string, :limit => 36
  end
end
