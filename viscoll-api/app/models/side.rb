# frozen_string_literal: true

class Side
  include Mongoid::Document
  include Mongoid::Timestamps

  # Fields
  field :page_number, type: String, default: nil
  field :texture, type: String, default: 'None'
  field :script_direction, type: String, default: 'None'
  field :image, type: Hash, default: -> { {} } # {manifestID: 123, label: "bla, " url: "https://iiif.library.utoronto.ca/image/v2/hollar:Hollar_a_3002_0001"}
  field :parentID, type: String
  field :side, type: String # either 'r' or 'v'

  # Relations
  belongs_to :project
  has_and_belongs_to_many :terms, inverse_of: nil

  # Callbacks
  before_destroy :unlink_terms, :unlink_image
  before_save :handle_empty_page_number

  def parent_leaf
    Leaf.find(parentID)
  end

  # if any terms are attached, mappings exist
  def mapping?
    return true if terms.present?

    texture != 'None'
  end

  def mappings
    mappings_array = []
    mappings_array.push({ texture => id.to_s }) if texture != 'None'
    terms.each do |term|
      mappings_array.push({ term.id => id })
    end
    mappings_array
  end

  def image_url
    return image['url'] if image['manifestID'].include? 'DIY'

    "#{image['url']}/full/,1000/0/default.jpg"
  end

  protected

  # If linked to term(s), remove link from the term(s)'s side
  def unlink_terms
    terms.each do |term|
      term.objects[:Recto].delete(id.to_s)
      term.objects[:Verso].delete(id.to_s)
      term.save
    end
  end

  # If linked to image, remove link from the image's sides list
  def unlink_image
    return if image.empty?
    return unless (image = Image.where(id: self.image[:url].split('/')[-1].split('_', 2)[0]).first)

    image.sideIDs.delete(id.to_s)
    image.save
  end

  def handle_empty_page_number
    self.page_number = nil if page_number.to_s.strip.empty?
  end
end
