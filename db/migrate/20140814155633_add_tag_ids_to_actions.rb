class AddTagIdsToActions < ActiveRecord::Migration
  def change
    add_column :actions, :tag_ids, :text, array: true, default: []
  end
end
