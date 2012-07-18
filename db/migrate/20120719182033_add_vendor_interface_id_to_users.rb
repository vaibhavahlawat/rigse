class AddVendorInterfaceIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :vendor_interface_id, :integer
  end
end
