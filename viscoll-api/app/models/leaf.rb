# frozen_string_literal: true

class Leaf
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :folio_number, type: String, default: nil
  field :material, type: String, default: 'None'
  field :type, type: String, default: 'Original'
  field :conjoined_to, type: String
  field :attached_above, type: String, default: 'None'
  field :attached_below, type: String, default: 'None'
  field :stubType, as: :stub, type: String, default: 'No'
  field :parentID, type: String
  field :nestLevel, type: Integer, default: 1
  field :rectoID, type: String
  field :versoID, type: String

  # Relations
  belongs_to :project
  has_and_belongs_to_many :terms, inverse_of: nil

  # Callbacks
  before_create :edit_ID, :create_sides
  before_destroy :unlink_terms, :destroy_sides, :update_parent_group
  before_save :handle_empty_folio_number

  def mapping?
    # if terms are attached to leaf, mappings exist
    return true if terms.present?

    # check sides for mappings
    recto = Side.find(rectoID)
    verso = Side.find(versoID)
    [recto, verso].compact.any?(&:mapping?)
  end

  def mappings
    mappings_array = []
    recto = Side.find(rectoID)
    verso = Side.find(versoID)
    mappings_array += recto.mappings if recto.mapping?
    mappings_array += verso.mappings if verso.mapping?
    terms.each do |term|
      mappings_array.push({ term.id => id })
    end
    mappings_array
  end

  def parent_project
    group = Group.find(parentID)
    Project.find(group.parentID)
  end

  # Remove itself from its parent group
  def remove_from_group
    Group.find(parentID).remove_members([id.to_s])
  end

  def top_level_group
    parent = Group.find(parentID)
    nest_level = parent.nestLevel
    while nest_level > 1
      parent = Group.find(parent.parentID)
      nest_level = parent.nestLevel
    end
    parent
  end

  def position_in_top_level_group
    top_level_group.all_leafIDs_in_order.index(id) + 1
  end

  protected

  def edit_ID
    self.id = "Leaf_#{id}" unless id.to_s[0] == 'L'
  end

  # If linked to term(s), remove link from the term(s)'s side
  def unlink_terms
    terms.each do |term|
      term.objects[:Leaf].delete(id.to_s)
      term.save
    end
  end

  # Create 2 sides(Recto & Verso) for this new leaf.
  def create_sides
    recto = Side.new({ parentID: id.to_s, project: project })
    verso = Side.new({ parentID: id.to_s, project: project })
    recto.id = "Recto_#{recto.id}"
    verso.id = "Verso_#{verso.id}"
    recto.save
    verso.save
    self.rectoID = recto.id
    self.versoID = verso.id
  end

  # Destroy its two sides
  def destroy_sides
    Side.find(rectoID).destroy
    Side.find(versoID).destroy
  end

  def update_attached_to
    project = Project.find(project_id)
    parent = project.groups.find(parentID)
    memberOrder = parent.memberIDs.index(id.to_s)
    if memberOrder.positive?
      # This leaf is not the first leaf in the group
      aboveLeaf = project.leafs.find(parent.memberIDs[memberOrder - 1])
      aboveLeaf.update(attached_below: attached_above)
    end
    return unless memberOrder < parent.memberIDs.length - 1

    belowLeaf = project.leafs.find(parent.memberIDs[memberOrder + 1])
    belowLeaf.update(attached_above: attached_below)
  end

  # Update leaf's parent Group's Tacketed & Sewing if it contains this leafID
  def update_parent_group
    group = Group.find(parentID)
    group.tacketed.include?(id.to_s) ? group.tacketed.delete(id.to_s) : nil
    group.sewing.include?(id.to_s) ? group.sewing.delete(id.to_s) : nil
    group.save
  end

  def handle_empty_folio_number
    self.folio_number = nil if folio_number.to_s.strip.empty?
  end
end
