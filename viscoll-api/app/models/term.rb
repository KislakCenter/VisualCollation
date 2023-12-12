# frozen_string_literal: true

class Term
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :title, type: String, default: 'None'
  field :taxonomy, type: String, default: ''
  field :description, type: String, default: ''
  field :uri, type: String, default: ''
  field :objects, type: Hash, default: { Group: [], Leaf: [], Recto: [], Verso: [] }
  field :show, type: Boolean, default: false

  # Relations
  belongs_to :project, inverse_of: :terms

  # Validations
  validates :title, presence: { message: 'Note title is required.' }
  validates :title, uniqueness: { message: 'Note title should be unique.', scope: :project }
  validates :taxonomy, presence: { message: 'Taxonomy is required.' }

  # Callbacks
  before_create :edit_ID
  before_destroy :update_objects_before_delete

  def edit_ID
    self.id = "Term_#{id}" unless id.to_s[0] == 'T'
  end

  def update_objects_before_delete
    objects[:Group].each do |groupID|
      if (group = Group.where(id: groupID).first)
        group.terms.delete(self)
        group.save
      end
    end
    objects[:Leaf].each do |leafID|
      if (leaf = Leaf.where(id: leafID).first)
        leaf.terms.delete(self)
        leaf.save
      end
    end
    objects[:Recto].each do |sideID|
      if (side = Side.where(id: sideID).first)
        side.terms.delete(self)
        side.save
      end
    end
    objects[:Verso].each do |sideID|
      if (side = Side.where(id: sideID).first)
        side.terms.delete(self)
        side.save
      end
    end
  end
end
