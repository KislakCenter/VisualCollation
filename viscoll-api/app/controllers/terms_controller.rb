class TermsController < ApplicationController
  before_action :authenticate!
  before_action :set_term, only: [:update, :link, :unlink, :destroy]
  before_action :set_attached_project, only: [:createTaxonomy, :deleteTaxonomy, :updateTaxonomy]

  # POST /terms
  def create
    @term = Term.new(term_create_params)
    @project = Project.find(@term.project_id)
    authorize_project! @project
    if @term.save
      if not Project.find(@term.project_id).taxonomies.include?(@term.taxonomy)
        @term.delete
        raise VCError, "Taxonomy (#{@term.taxonomy}) does not belong to project (#{@project.id})."
      end
    else
      raise VCError, "Something went wrong with saving terms: #{@term.errors}"
    end
  end

  # PATCH/PUT /terms/1
  def update
    taxonomy = term_update_params.to_h[:taxonomy]
    if not Project.find(@term.project_id).taxonomies.include?(taxonomy)
      raise VCError, "Taxonomy (#{@term.taxonomy}) does not belong to project (#{@project.id})."
    end
    if !@term.update(term_update_params)
      raise VCError, "Term (#{@term.id}) could not update: #{@term.errors.join "\n"}"
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
      case type
      when "Group"
        @object    = Group.find(id)
        authorized = @object.project.user_id == current_user.id
      when "Leaf"
        @object    = Leaf.find(id)
        authorized = @object.project.user_id == current_user.id
      when "Recto", "Verso"
        @object    = Side.find(id)
        authorized = @object.project.user_id == current_user.id
      else
        raise VCError, "Object not found with type: #{type}"
      end
      unless authorized
        raise VCError, "Action not authorized."
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
      case type
      when "Group"
        @object    = Group.find(id)
        authorized = @object.project.user_id == current_user.id
      when "Leaf"
        @object    = Leaf.find(id)
        authorized = @object.project.user_id == current_user.id
      when "Recto", "Verso"
        @object    = Side.find(id)
        authorized = @object.project.user_id == current_user.id
      else
        raise VCError, "Object not found with type: #{type}"
      end
      unless authorized
        raise VCError, "Action not authorized."
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
      raise VCError, "Taxonomy (#{taxonomy}) already exists in the project (#{@project.id})"
    else
      @project.taxonomies.push(taxonomy)
      @project.save
    end
  end


  # DELETE /terms/taxonomy
  def deleteTaxonomy
    taxonomy = taxonomy_params.to_h[:taxonomy]
    if not @project.taxonomies.include?(taxonomy)
      raise VCError, "Taxonomy (#{taxonomy}) does not exist in the project (#{@project.id})"
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
    taxonomy = taxonomy_params.to_h[:taxonomy]
    if not @project.taxonomies.include?(old_taxonomy)
      raise VCError, "Taxonomy (#{taxonomy}) does not exist in the project (#{@project.id})"
    elsif @project.taxonomies.include?(taxonomy)
      raise VCError, "Taxonomy (#{taxonomy}) already exists in the project (#{@project.id})"
    else
      indexToEdit = @project.taxonomies.index(old_taxonomy)
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
        term_id = if params[:id].include? 'Term_'
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
        @project = Project.find(project_id)
        authorize_project! @project
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
