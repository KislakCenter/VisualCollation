class ImportController < ApplicationController
  INVALID_IMPORT_MESSAGE = "Sorry, the imported data cannot be validated. Please check your file for errors and make sure the correct import format is selected above.".freeze

  before_action :authenticate!

  # PUT /projects/import
  def index
    importData   = imported_data.to_h[:importData]
    importFormat = imported_data.to_h[:importFormat]
    imageData    = imported_data.to_h[:imageData]
    case importFormat
    when "json"
      handleJSONImport(JSON.parse(importData))
    when "xml"
      xml     = Nokogiri::XML(importData)
      schema  = Nokogiri::XML::RelaxNG(File.open("public/viscoll-datamodel2.rng"))
      schema2 = Nokogiri::XML::RelaxNG(File.open("public/viscoll-datamodel2.0.rng"))
      errors  = schema.validate(xml)
      errors2 = schema2.validate(xml)
      if errors.empty? || errors2.empty?
        handleXMLImport(xml)
      else
        raise VCError.new("XML import failed: #{(errors + errors2).join "\n"}", status: :unprocessable_entity)
      end
    end
    newProject = current_user.projects.order_by(:updated_at => 'desc').first
    handleMappingImport(newProject, imageData, current_user)
    current_user.reload
    @projects = current_user.projects.order_by(:updated_at => 'desc')
    @images   = current_user.images
    render :'projects/index', status: :ok and return
  rescue JSON::ParserError => error
    raise VCError.new(INVALID_IMPORT_MESSAGE, status: :unprocessable_entity)
  end

  private

  # Never trust parameters from the scary Internet, only allow the white list through.
  def imported_data
    params.permit(:importData, :importFormat, :imageData)
  end

end
