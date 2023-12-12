# frozen_string_literal: true

class FeedbackController < ApplicationController
  before_action :authenticate!

  # POST /feedback
  def create
    render json: {}, status: :unprocessable_entity and return unless current_user

    @title = feedback_params[:title]
    @message = feedback_params[:message]
    @browserInformation = feedback_params[:browserInformation]
    @projectJSONExport = feedback_params[:project]
    raise VCError, 'Title and message required.' if @title.blank? || @message.blank?

    FeedbackMailer.sendFeedback(
      @title,
      @message,
      @browserInformation,
      @projectJSONExport,
      current_user
    ).deliver_now
    render json: {}, status: :ok and return
  end

  private

  def feedback_params
    params.require(:feedback).permit(:title, :message, :browserInformation, :project)
  end
end
