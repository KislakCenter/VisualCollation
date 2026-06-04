class User
  include Mongoid::Document
  include RailsJwtAuth::Authenticatable
  include RailsJwtAuth::Confirmable
  include RailsJwtAuth::Recoverable
  include RailsJwtAuth::Trackable
  
  field :name, type: String, default: ""

  before_save { self.email = email.to_s.downcase }

  has_many :images, dependent: :destroy
  has_many :projects, dependent: :destroy

end
