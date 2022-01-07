class XprocController < ApplicationController
  before_action :authenticate!, except: [:show, :get_zip]

  # GET /xproc/zip/:job_id
  def get_zip
    job_id        = params[:job_id]
    zip_file_path = "#{Rails.root}/public/xproc/#{job_id}.zip"
    send_file zip_file_path, :type => 'application/zip', :disposition => 'inline'
  end

  private

  def zip_params
    params.permit(:job_id)
  end

end
