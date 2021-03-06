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
  field :groupIDs, type: Array, default: []

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

  # do any groups have mappings?
  def mapping?
    groups.any? { |group| group.mapping? }
  end

  def text_direction
    'l-r'
  end

  def recto_side
    if text_direction == 'l-r'
      'left'
    else
      'right'
    end
  end

  def verso_side
    if text_direction == 'l-r'
      'right'
    else
      'left'
    end
  end

  def mappings
    mappings_array = []
    self.groups.each do |group|
      mappings_array += group.mappings if group.mapping?
    end
    mappings_array
  end

  def add_groupIDs(groupIDs, index)
    if self.groupIDs.length == 0
      self.groupIDs = groupIDs
    else
      self.groupIDs.insert(index, *groupIDs)
    end
    self.save()
  end

  def remove_groupID(groupID)
    self.groupIDs.delete(groupID)
    self.save()
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
