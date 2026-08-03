class FeedbackController < ApplicationController
  before_action :authenticate!

  # POST /feedback
  def create
      unless current_user
        render json: {}, status: :unprocessable_entity and return
      end
      @title = feedback_params[:title]
      @message = feedback_params[:message]
      @browserInformation = feedback_params[:browserInformation]
      @projectJSONExport = feedback_params[:project]
      if @title.blank? or @message.blank?
        raise VCError.new("[title] and [message] params required.", status: :unprocessable_entity)
      end
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
