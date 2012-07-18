class AddNamesToUsers < ActiveRecord::Migration
  def change
    add_column :users, :first_name, :string, :limit => 100, :default => ""
    add_column :users, :last_name, :string, :limit => 100, :default => ""
  end
end
