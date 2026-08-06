class ImagesController < ApplicationController
  before_action :authenticate!, except: [:show, :getZipImages]
  before_action :set_image_projects, :authorize_image_projects!, only: [:uploadImages, :link, :unlink]
  before_action :set_images, :authorize_images!, only: [:link, :unlink, :destroy]

  # POST /images
  def uploadImages
    projectIDs = @image_projects.map(&:id).map(&:to_s)
    newImages = []
    allImages = image_create_params.to_h[:images]
    allImages.each do |image_data|
      filename      = image_data[:filename].parameterize.underscore
      extension     = image_data[:content].split("image/").last.split(";base64").first
      imageIO       = Shrine.data_uri(image_data[:content])
      uploader      = Shrine.new(:store)
      uploaded_file = uploader.upload(imageIO, metadata: { "filename" => "#{filename}.#{extension}" })
      image         = Image.new(user: current_user, filename: "#{filename}.#{extension}", fileID: uploaded_file.id, metadata: uploaded_file.metadata, projectIDs: projectIDs)
      if image.valid?
        image.save
      else
        copyCounter = 1
        while !image.save do
          if image.errors.key?("filename") and image.errors[:filename][0].include?("Image with filename")
            # Duplicate filename. Create Image with new filename+"_copy(copyCounter)"
            filename    = "#{image_data[:filename].parameterize.underscore}_copy(#{copyCounter})"
            image       = Image.new(user: current_user, filename: "#{filename}.#{extension}", fileID: uploaded_file.id, metadata: uploaded_file.metadata, projectIDs: projectIDs)
            copyCounter += 1
          else
            image.destroy
            render(json: { error: "Image failed: #{image.errors.full_messages.join("\n")}"}, status: :unprocessable_entity) and return
          end
        end
      end
      newImages.push(image)
    end
    @projects = current_user.projects
    @images   = newImages
    render :'projects/index', status: :ok and return
  end

  # GET /images/:imageID
  def show
    begin
      imageID  = params[:imageID_filename].split("_", 2)[0]
      @image   = Image.find(imageID)
    rescue Mongoid::Errors::DocumentNotFound
      render(json: { error: "Image not found with id #{imageID}" }, status: :not_found) and return
    end

    filename = params[:imageID_filename].split("_", 2)[1]
    # Get image file
    path = "#{Rails.root}/public/uploads/#{@image.fileID}"
    File.open(path, 'rb') do |image|
      send_file image, :type => @image.metadata['mime_type'], :disposition => 'inline'
    end
  end

  # GET /images/zip/:imageID_projectID
  def getZipImages
    projectID   = params[:id]
    zipFilePath = "#{Rails.root}/public/uploads/#{projectID}_images.zip"
    send_file zipFilePath, :type => 'application/zip', :disposition => 'inline'
  end

  # PUT/PATCH /images/link
  def link
    @image_projects.each do |project|
      @images.each do |image|
        if not image.projectIDs.include? project.id.to_s
          image.projectIDs.push(project.id.to_s)
          image.save
        end
      end
    end

    @projects = current_user.projects
    @images   = current_user.images
    render :'projects/index', status: :ok and return
  end

  # PUT/PATCH /images/unlink
  def unlink
    @image_projects.each do |project|
      @images.each do |image|
        if image.projectIDs.include? project.id.to_s
          image.projectIDs.delete(project.id.to_s)
          # Unlink All Sides that belongs to this Project that has this Image mapped to it.
          image.sideIDs.each do |sideID|
            side = project.sides.where(:id => sideID).first
            if side
              side.image = {}
              side.save
              image.sideIDs.delete(sideID)
            end
          end
          image.save
        end
      end
    end
    @projects = current_user.projects
    @images   = current_user.images
    render :'projects/index', status: :ok and return
  end

  # DELETE /images
  def destroy
    @images.each do |image|
      image.destroy
    end

    @projects = current_user.projects
    @images   = current_user.images
    render :'projects/index', status: :ok and return
  end

  private

  def set_images
    image_ids = params[:imageIDs]

    @images = image_ids.map do |image_id|
      begin
        Image.find(image_id.split("_", 2)[0])
      rescue Mongoid::Errors::DocumentNotFound
        render(json: { error: "Image not found with id #{image_id}" }, status: :not_found) and return
      end
    end
  end

  def authorize_images!
    @images.each do |image|
      if current_user.id != image.user_id
        render(json: { error: "Image is not authorized for current user." }, status: :forbidden) and return
      end
    end
  end

  # Set the list of projects for the image.
  def set_image_projects
    project_ids = Array.wrap(params[:projectID] || params[:projectIDs])

    @image_projects = project_ids.map do |project_id|
      begin
        Project.find(project_id)
      rescue Mongoid::Errors::DocumentNotFound
        render(json: { error: "Project not found with id #{project_id}" }, status: :not_found) and return
      end
    end
  end

  # Validate that all image projects can be edited by the current_user.
  def authorize_image_projects!
    @image_projects.each do |project|
      if current_user.id != project.user_id
        render(json: { error: "Project is not authorized for current user." }, status: :forbidden) and return
      end
    end
  end

  def image_create_params
    params.permit(:projectID, :images => [:filename, :content])
  end

  def images_destroy_params
    params.permit(:imageIDs => [])
  end

  def image_link_unlink_params
    params.permit(:projectIDs => [], :imageIDs => [])
  end
end
