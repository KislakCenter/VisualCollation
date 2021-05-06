class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :title, type: String
  field :shelfmark, type: String # (eg) "MS 1754"
  field :notationStyle, type: String, default: "r-v" # (eg) "r-v"
  field :metadata, type: Hash, default: lambda { { } } # (eg) {date: "19th century"}
  field :manifests, type: Hash, default: lambda { { } } # (eg) { "1234556": { id: "123456, url: ""} }
  field :taxonomies, type: Array, default: ["Unknown"] # custom taxonomies
  field :preferences, type: Hash, default: lambda { { :showTips => true } }
  field :topLevelGroupIDs, type: Array, default: []
  # field :groupIDs, type: Array, default: []

  # Relations
  belongs_to :user, inverse_of: :projects
  has_many :groups, dependent: :delete
  has_many :leafs, dependent: :delete
  has_many :sides, dependent: :delete
  has_many :terms, dependent: :delete

  # Callbacks
  before_destroy :unlink_images_before_delete

  # Validations
  validates_presence_of :title, :message => "Project title is required."
  validates_uniqueness_of :title, :message => "Project title: '%{value}', must be unique.", scope: :user

  def groupIDs
    ids = []
    self.topLevelGroupIDs.each do |tl|
      group = Group.find tl
      get_groupIDs group, ids
    end
    ids.flatten
  end

  def get_groupIDs group, ids
    ids << group.id unless ids.include? group.id
    group.memberIDs.each do |id|
      if id.starts_with? 'G'
        subgroup = Group.find id
        get_groupIDs subgroup, ids
      end
    end
    ids.flatten
  end

  def add_groupIDs(groupIDs, index)
    top_level_groups = groupIDs.select {|id| Group.find(id).nestLevel == 1}
    if self.topLevelGroupIDs.length == 0
      self.topLevelGroupIDs = top_level_groups
    else
      self.topLevelGroupIDs.insert(index, *top_level_groups)
    end
    self.save
  end

  def remove_groupID(groupID)
    self.topLevelGroupIDs.delete(groupID)
    self.save
  end

  def unlink_images_before_delete
    Image.where(:user_id => self.user.id).each do |image|
      # Unlink All Sides that belongs to this Project that has this Image mapped to it.
      image.sideIDs.each do |sideID|
        side = self.sides.where(:id => sideID).first
        if side
          side.image = {}
          side.save
          image.sideIDs.include?(sideID) ? image.sideIDs.delete(sideID) : nil
        end
      end
      image.projectIDs.include?(self.id.to_s) ? image.projectIDs.delete(self.id.to_s) : nil
      image.save
    end
  end
end
