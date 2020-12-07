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

  def group_notation
    outer_groups = project.groups.where(nestLevel: 1).to_a
    groupIDs = outer_groups.map(&:id)
    puts outer_groups.inspect
    puts groupIDs.inspect
    if self.nestLevel == 1
      quire_order = groupIDs.index(self.id) + 1 # index of this group (self.id) in context of outer_groups + 1
      notation = quire_order.to_s
    else
      puts 'line 32'
      # get parent group
      parent_group = Group.find(self.parentID)
      puts "parent: #{parent_group}" 
      puts "memberIDs: #{parent_group.memberIDs}"
      # get memberIDs from parent group that start with 'G'
      quire_children = parent_group.memberIDs.select{ |g| g.start_with? 'G'}
      puts "children: #{quire_children}" 
      # find this group in context of above array
      quire_order = parent_group.group_notation # index of this group's parent (self.parentID) in context of all groups
      subquire_order = quire_children.index(self.id) + 1 # index of this group in context of all children of this group's parent
      notation = "#{quire_order}.#{subquire_order}"
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

end
