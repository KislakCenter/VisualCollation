class TermsController < ApplicationController
  TERM_OBJECT_MODELS = {
    "Group" => Group,
    "Leaf" => Leaf,
    "Recto" => Side,
    "Verso" => Side
  }.freeze

  before_action :authenticate!
  before_action :set_term, only: [:update, :link, :unlink, :destroy]
  before_action :set_attached_project, only: [:createTaxonomy, :deleteTaxonomy, :updateTaxonomy]

  # POST /terms
  def create
    @term    = Term.new(term_create_params)
    @project = find_term_project(@term.project_id)
    return unless @project

    return unless authorize_project! @project
    if @term.save
      if not Project.find(@term.project_id).taxonomies.include?(@term.taxonomy)
        @term.delete
        options = @project.taxonomies
        return render_error("Invalid taxonomy", status: :unprocessable_entity, json: { taxonomy: ["should be one of #{options}"] })
      end
    else
      return render_error("Term could not be saved", status: :unprocessable_entity, json: @term.errors)
    end
  end

  # PATCH/PUT /terms/1
  def update
    taxonomy = term_update_params.to_h[:taxonomy]
    if not Project.find(@term.project_id).taxonomies.include?(taxonomy)
      options = Project.find(@term.project_id).taxonomies
      return render_error("Invalid taxonomy", status: :unprocessable_entity, json: { taxonomy: "should be one of #{options}" })
    end
    if !@term.update(term_update_params)
      return render_error("Term (#{@term.id}) could not update: #{@term.errors.full_messages.join "\n"}", status: :unprocessable_entity)
    end
  end

  # DELETE /terms/1
  def destroy
    @term.destroy
  end

  # PUT /terms/1/link
  def link
    objects = term_object_link_params.to_h[:objects]
    objects.each do |object|
      type = object[:type]
      id   = object[:id]
      @object = find_term_object(type, id)
      return unless @object

      authorized = @object.project.user_id == current_user.id
      unless authorized
        return render_error("Action not authorized.", status: :unauthorized)
      end
      @object.terms.push(@term)
      @object.save
      if (not @term.objects[type].include?(id))
        @term.objects[type].push(id)
      end
      @term.save
    end
  end

  # PUT /terms/1/unlink
  def unlink
    objects = term_object_link_params.to_h[:objects]
    objects.each do |object|
      type = object[:type]
      id   = object[:id]
      @object = find_term_object(type, id)
      return unless @object

      authorized = @object.project.user_id == current_user.id
      unless authorized
        return render_error("Action not authorized.", status: :unauthorized)
      end
      @object.terms.delete(@term)
      @object.save
      @term.objects[type].delete(id)
      @term.save
    end
  end

  # POST /terms/taxonomy
  def createTaxonomy
    taxonomy = taxonomy_params.to_h[:taxonomy]
    if @project.taxonomies.include?(taxonomy)
      return render_error("Duplicate taxonomy", status: :unprocessable_entity, json: { taxonomy: "#{taxonomy} taxonomy already exists in the project" })
    else
      @project.taxonomies.push(taxonomy)
      @project.save
    end
  end

  # DELETE /terms/taxonomy
  def deleteTaxonomy
    taxonomy = taxonomy_params.to_h[:taxonomy]
    if not @project.taxonomies.include?(taxonomy)
      return render_error("Unknown taxonomy", status: :unprocessable_entity, json: { taxonomy: "#{taxonomy} taxonomy doesn't exist in the project" })
    else
      @project.taxonomies.delete(taxonomy)
      @project.save
      @project.terms.where(taxonomy: taxonomy).each do |term|
        term.update(taxonomy: "Unknown")
        term.save
      end
    end
  end

  # PUT /terms/taxonomy
  def updateTaxonomy
    old_taxonomy = taxonomy_params.to_h[:old_taxonomy]
    taxonomy     = taxonomy_params.to_h[:taxonomy]
    if not @project.taxonomies.include?(old_taxonomy)
      return render_error("Unknown taxonomy", status: :unprocessable_entity, json: { old_taxonomy: "#{old_taxonomy} taxonomy doesn't exist in the project" })
    elsif @project.taxonomies.include?(taxonomy)
      return render_error("Duplicate taxonomy", status: :unprocessable_entity, json: { taxonomy: "#{taxonomy} already exists in the project" })
    else
      indexToEdit                      = @project.taxonomies.index(old_taxonomy)
      @project.taxonomies[indexToEdit] = taxonomy
      @project.save
      @project.terms.where(taxonomy: old_taxonomy).each do |term|
        term.update(taxonomy: taxonomy)
        term.save
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_term
    # when the ID is first sent to the backend to be created,
    # it doesn't have 'Term_' - we need to append it in the
    # controller in order for our Mongo query to execute
    term_id  = if params[:id].include? 'Term_'
                 params[:id]
               else
                 'Term_' + params[:id]
               end
    @term    = Term.find(term_id)
    @project = Project.find(@term.project_id)
    authorize_project! @project
  end

  def set_attached_project
    project_id = taxonomy_params.to_h[:project_id]
    @project = find_term_project(project_id)
    return unless @project

    authorize_project! @project
  end

  def find_term_object(type, id)
    model = TERM_OBJECT_MODELS[type]
    unless model
      render_error("Unknown object type", status: :unprocessable_entity, json: { type: "object not found with type #{type}" })
      return
    end

    model.find(id)
  rescue Mongoid::Errors::DocumentNotFound => error
    render_error(error, status: :unprocessable_entity, json: { id: "#{type} object not found with id #{id}" })
    nil
  end

  def find_term_project(project_id)
    Project.find(project_id)
  rescue Mongoid::Errors::DocumentNotFound => error
    message = "project not found with id #{project_id}"
    render_error(error, status: :unprocessable_entity, json: { project_id: message })
    nil
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def term_create_params
    params.require(:term).permit(:project_id, :id, :title, :taxonomy, :description, :uri, :show)
  end

  def term_update_params
    params.require(:term).permit(:title, :taxonomy, :description, :uri, :show)
  end

  def term_object_link_params
    params.permit(:objects => [:id, :type])
  end

  def taxonomy_params
    params.require(:taxonomy).permit(:taxonomy, :project_id, :old_taxonomy)
  end

end
