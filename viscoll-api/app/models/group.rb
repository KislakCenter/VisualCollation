class Group
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :title, type: String, default: "None"
  field :type, type: String, default: "Quire"
  field :tacketed, type: Array, default: []
  field :sewing, type: Array, default: []
  field :nestLevel, type: Integer, default: 1
  field :parentID, type: String
  field :memberIDs, type: Array, default: [] # eg [ id1, id2, ... ]

  # Relations
  belongs_to :project
  has_and_belongs_to_many :terms, inverse_of: nil

  # Callbacks
  before_create :edit_ID
  before_destroy :unlink_terms, :unlink_project, :unlink_group, :destroy_members

  def mapping?
    # if any terms are attached to group, mappings exist
    return true if terms.present?
    memberIDs.any? do |memberID|
      if memberID[0] == 'G'
        member = Group.find(memberID)
      elsif memberID[0] == 'L'
        member = Leaf.find(memberID)
      end
      member.mapping?
    end
  end

  def mappings
    mappings_array = []
    self.memberIDs.each do |memberID|
      if memberID[0] == "L"
        member = Leaf.find(memberID)
        mappings_array += member.mappings if member.mapping?
      end
    end
    mappings_array
  end

  # code here must mirror groupNotation function in PaperManager.js:44
  def group_notation
    outer_groups = project.groups.where(nestLevel: 1).to_a
    outer_groupIDs = outer_groups.map(&:id)
    if self.nestLevel == 1
      group_order = outer_groupIDs.index(self.id) + 1 # index of this group (self.id) in context of outer_groups + 1
      notation = group_order.to_s
    else
      parent_group = Group.find(self.parentID)
      parent_group_children = parent_group.memberIDs.select{ |g| g.start_with? 'G'}
      subquire_notation = parent_group_children.index(self.id) + 1 # index of this group in context of all children of this group's parent
      notation = "#{parent_group.group_notation}.#{subquire_notation}"
    end
    notation
  end

  def edit_ID
    self.id = "Group_"+self.id.to_s unless self.id.to_s[0] == "G"
  end

  # Add new members to this group
  def add_members(memberIDs, startOrder, save=true)
    if self.memberIDs.length==0
      self.memberIDs = memberIDs
    elsif
      self.memberIDs.insert(startOrder-1, *memberIDs)
    end
    if save
      self.save
    end
    return self
  end

  def remove_members(ids)
    newList = self.memberIDs.reject{|id| ids.include?(id)}
    self.memberIDs = newList
    self.save
  end

  # If linked to term(s), remove link from the term(s)'s side
  def unlink_terms
    if self.terms
      self.terms.each do | term |
        term.objects[:Group].delete(self.id.to_s)
        term.save
      end
    end
  end

  # Remove itself from project
  def unlink_project
    self.project.remove_groupID(self.id.to_s)
  end

  # Remove itself from parent group (if nested)
  def unlink_group
    if self.parentID != nil
      Group.find(self.parentID).remove_members([self.id.to_s])
    end
  end

  def destroy_members
    self.memberIDs.each do | memberID |
      if memberID[0] === "G"
        Group.find(memberID).destroy
      elsif memberID[0] === "L"
        Leaf.find(memberID).destroy
      end
    end
  end

  def all_leafIDs_in_order
    return @child_leafs if @child_leafs.present?
    @child_leafs = []
    memberIDs.each do |memberID|
      if memberID[0] === "G"
        @child_leafs += Group.find(memberID).all_leafIDs_in_order
      elsif memberID[0] === "L"
        @child_leafs << memberID
      end
    end
    @child_leafs
  end

end
