class AddStarToActions < ActiveRecord::Migration
  def change
    add_column :actions, :star, :boolean
  end
end
