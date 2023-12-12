# frozen_string_literal: true

class Project
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :title, type: String
  field :shelfmark, type: String # (eg) "MS 1754"
  field :notationStyle, type: String, default: 'r-v' # (eg) "r-v"
  field :metadata, type: Hash, default: -> { {} } # (eg) {date: "19th century"}
  field :manifests, type: Hash, default: -> { {} } # (eg) { "1234556": { id: "123456, url: ""} }
  field :taxonomies, type: Array, default: ['Unknown'] # custom taxonomies
  field :preferences, type: Hash, default: -> { { showTips: true } }
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
  validates :title, presence: { message: 'Project title is required.' }
  validates :title, uniqueness: { message: "Project title: '%<value>s', must be unique.", scope: :user }

  # do any groups have mappings?
  def mapping?
    groups.any?(&:mapping?)
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
    groups.each do |group|
      mappings_array += group.mappings if group.mapping?
    end
    mappings_array
  end

  def add_groupIDs(groupIDs, index)
    if self.groupIDs.empty?
      self.groupIDs = groupIDs
    else
      self.groupIDs.insert(index, *groupIDs)
    end
    save
  end

  def remove_groupID(groupID)
    groupIDs.delete(groupID)
    save
  end

  def unlink_images_before_delete
    Image.where(user_id: user.id).find_each do |image|
      # Unlink All Sides that belongs to this Project that has this Image mapped to it.
      image.sideIDs.each do |sideID|
        side = sides.where(id: sideID).first
        next unless side

        side.image = {}
        side.save
        image.sideIDs.include?(sideID) ? image.sideIDs.delete(sideID) : nil
      end
      image.projectIDs.include?(id.to_s) ? image.projectIDs.delete(id.to_s) : nil
      image.save
    end
  end
end
