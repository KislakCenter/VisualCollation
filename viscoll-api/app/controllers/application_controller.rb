class ApplicationController < ActionController::API
    rescue_from StandardError do |error|
      render_error(error, status: :unprocessable_entity, report: true)
    end

    rescue_from Mongoid::Errors::DocumentNotFound do |error|
      render_error(error, status: :not_found)
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

    def render_error(error, status:, json: nil, report: false)
      message = error.respond_to?(:message) ? error.message : error.to_s

      report_error(error, message) if report
      Rails.logger.warn(message) unless report
      render json: json || { error: message }, status: status
    end

    def find_document(model, id)
      model.find(id)
    rescue Mongoid::Errors::DocumentNotFound => error
      message = "#{model.name.downcase} not found with id #{id}"
      render_error(error, status: :not_found, json: { error: message })
      nil
    end

    def report_error(error, message)
      Rails.logger.error(([message] + Array(error.backtrace)).join("\n"))
      Honeybadger.notify(error)
    end
end
