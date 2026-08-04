class ApplicationController < ActionController::API
    # Carries the HTTP status (and optional structured body) for expected
    # errors raised across controllers. `raise` halts execution, so callers
    # need no return guards (render alone does not stop an action).
    class VCError < StandardError
      attr_reader :status, :json

      def initialize(message = nil, status: :unprocessable_entity, json: nil)
        super(message)
        @status = status
        @json = json
      end
    end

    rescue_from StandardError do |error|
      Honeybadger.notify(error)
      Rails.logger.error(error.message + "\n" + error.backtrace.join("\n"))
      render json: { error: error.message }, status: :unprocessable_entity
    end

    # Registered after StandardError so the more specific handlers below are matched first.
    rescue_from Mongoid::Errors::DocumentNotFound do |error|
      render json: { error: error.message }, status: :not_found
    end

    rescue_from VCError do |error|
      Rails.logger.warn(error.message)
      render json: { error: error.message }.merge(error.json || {}), status: error.status
    end

    before_action :set_base_api_url
    def set_base_api_url
      # TODO: we need an env var with a complete URL for this
      @base_api_url = Rails.application.secrets.api_url ? Rails.application.secrets.api_url : "https://#{ENV['APPLICATION_HOST']}"
    end

    include RailsJwtAuth::WardenHelper
    include ControllerHelper::ProjectsHelper
    include ControllerHelper::GroupsHelper
    include ControllerHelper::LeafsHelper
    include ControllerHelper::FilterHelper
    include ControllerHelper::ImportJsonHelper
    include ControllerHelper::ImportXmlHelper
    include ControllerHelper::ImportMappingHelper
    include ControllerHelper::ExportHelper
    include ValidationHelper::ProjectValidationHelper
    include ValidationHelper::GroupValidationHelper
    include ValidationHelper::LeafValidationHelper

    private

    def find_document(model, id, status: :not_found)
      model.find(id)
    rescue Mongoid::Errors::DocumentNotFound
      raise VCError.new("#{model.name.downcase} not found with id #{id}", status: status)
    end
end
