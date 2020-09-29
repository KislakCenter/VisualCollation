class TermsController < ApplicationController
  before_action :authenticate!
  before_action :set_term, only: [:update, :link, :unlink, :destroy]
  before_action :set_attached_project, only: [:createType, :deleteType, :updateType]

  # POST /terms
  def create
    @term = Term.new(term_create_params)
    begin
      @project = Project.find(@term.project_id)
    rescue Mongoid::Errors::DocumentNotFound
      render json: {project_id: "project not found with id "+@term.project_id}, status: :unprocessable_entity and return
    end
    if @project.user != current_user
      render json: {error: ''}, status: :unauthorized and return
    end
    if @term.save
      if not Project.find(@term.project_id).noteTypes.include?(@term.type)
        @term.delete
        render json: {type: "should be one of " +Project.find(@term.project_id).noteTypes.to_s}, status: :unprocessable_entity and return
      end
    else
      render json: @term.errors, status: :unprocessable_entity and return
    end
  end

  # PATCH/PUT /terms/1
  def update
    type = term_update_params.to_h[:type]
    if not Project.find(@term.project_id).noteTypes.include?(type)
      render json: {type: "should be one of " +Project.find(@term.project_id).noteTypes.to_s}, status: :unprocessable_entity and return
    end
    if !@term.update(term_update_params)
      render json: @term.errors, status: :unprocessable_entity and return
    end
  end

  # DELETE /terms/1
  def destroy
    @term.destroy
  end

  # PUT /terms/1/link
  def link
    begin
      objects = term_object_link_params.to_h[:objects]
      objects.each do |object|
        type = object[:type]
        id = object[:id]
        begin
          case type
          when "Group"
            @object = Group.find(id)
            authorized = @object.project.user_id == current_user.id
          when "Leaf"
            @object = Leaf.find(id)
            authorized = @object.project.user_id == current_user.id
          when "Recto", "Verso"
            @object = Side.find(id)
            authorized = @object.project.user_id == current_user.id
          else
            render json: {type: "object not found with type "+type}, status: :unprocessable_entity and return
          end
          unless authorized
            render json: {error: ''}, status: :unauthorized and return
          end
        rescue Mongoid::Errors::DocumentNotFound
          render json: {id: type + " object not found with id "+id}, status: :unprocessable_entity and return
        end
        @object.terms.push(@term)
        @object.save
        if (not @term.objects[type].include?(id))
          @term.objects[type].push(id)
        end
        @term.save
      end
    rescue Exception => e
      render json: {error: e.message}, status: :unprocessable_entity and return
    end
  end

  # PUT /terms/1/unlink
  def unlink
    begin
      objects = term_object_link_params.to_h[:objects]
      objects.each do |object|
        type = object[:type]
        id = object[:id]
        begin
          case type
          when "Group"
            @object = Group.find(id)
            authorized = @object.project.user_id == current_user.id
          when "Leaf"
            @object = Leaf.find(id)
            authorized = @object.project.user_id == current_user.id
          when "Recto", "Verso"
            @object = Side.find(id)
            authorized = @object.project.user_id == current_user.id
          else
            render json: {type: "object not found with type "+type}, status: :unprocessable_entity and return
          end
          unless authorized
            render json: {error: ''}, status: :unauthorized and return
          end
        rescue Mongoid::Errors::DocumentNotFound
          render json: {id: type + " object not found with id "+id}, status: :unprocessable_entity and return
        end
        @object.terms.delete(@term)
        @object.save
        @term.objects[type].delete(id)
        @term.save
      end
    rescue Exception => e
      render json: {error: e.message}, status: :unprocessable_entity and return
    end
  end



  # POST /terms/type
  def createType
    type = note_type_params.to_h[:type]
    if @project.noteTypes.include?(type)
      render json: {type: type+" type already exists in the project"}, status: :unprocessable_entity and return
    else
      @project.noteTypes.push(type)
      @project.save
    end
  end


  # DELETE /terms/type
  def deleteType
    type = note_type_params.to_h[:type]
    if not @project.noteTypes.include?(type)
      render json: {type: type+" type doesn't exist in the project"}, status: :unprocessable_entity and return
    else
      @project.noteTypes.delete(type)
      @project.save
      @project.terms.where(type: type).each do |term|
        term.update(type: "Unknown")
        term.save
      end
    end
  end


  # PUT /terms/type
  def updateType
    old_type = note_type_params.to_h[:old_type]
    type = note_type_params.to_h[:type]
    if not @project.noteTypes.include?(old_type)
      render json: {old_type: old_type+" type doesn't exist in the project"}, status: :unprocessable_entity and return
    elsif @project.noteTypes.include?(type)
      render json: {type: type+" already exists in the project"}, status: :unprocessable_entity and return
    else
      indexToEdit = @project.noteTypes.index(old_type)
      @project.noteTypes[indexToEdit] = type
      @project.save
      @project.terms.where(type: old_type).each do |term|
        term.update(type: type)
        term.save
      end
    end
  end



  private
    # Use callbacks to share common setup or constraints between actions.
    def set_term
      begin
        @term    = Term.find(params[:id])
        @project = Project.find(@term.project_id)
        if (@project.user_id!=current_user.id)
          render json: {error: ""}, status: :unauthorized and return
        end
      rescue Mongoid::Errors::DocumentNotFound
        render json: {error: "note not found with id "+params[:id]}, status: :not_found and return
      rescue Exception => e
        render json: {error: e.message}, status: :unprocessable_entity and return
      end
    end

    def set_attached_project
      project_id = note_type_params.to_h[:project_id]
      begin
        @project = Project.find(project_id)
        if @project.user_id != current_user.id
          render json: {error: ""}, status: :unauthorized and return
        end
      rescue Mongoid::Errors::DocumentNotFound
        render json: {project_id: "project not found with id "+project_id}, status: :unprocessable_entity and return
      end
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def term_create_params
      params.require(:term).permit(:project_id, :id, :title, :type, :description, :uri, :show)
    end

    def term_update_params
      params.require(:term).permit(:title, :type, :description, :uri, :show)
    end

    def term_object_link_params
      params.permit(:objects => [:id, :type])
    end

    def note_type_params
      params.require(:noteType).permit(:type, :project_id, :old_type)
    end


end