class AddNsrs < ActiveRecord::Migration[5.2]
  def change
    add_column :requests, :nsr, :string
  end
end
