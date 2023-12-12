# frozen_string_literal: true

class LeafsController < ApplicationController
  before_action :authenticate!
  before_action :set_leaf, only: %i[update destroy]

  # POST /leafs
  def create
    memberOrder      = additional_params.to_h[:memberOrder]
    noOfLeafs        = additional_params.to_h[:noOfLeafs]
    conjoin          = additional_params.to_h[:conjoin]
    oddMemberLeftOut = additional_params.to_h[:oddMemberLeftOut]
    leafIDs          = additional_params.to_h[:leafIDs]
    sideIDs          = additional_params.to_h[:sideIDs]
    project_id       = leaf_params.to_h[:project_id]
    parentID         = leaf_params.to_h[:parentID]

    # Validation error for leaf_params
    @leafErrors = validateLeafParams(project_id, parentID)
    if @leafErrors[:project_id].length.positive? || @leafErrors[:parentID].length.positive?
      raise VCError, "Leaf validation failed: #{@leafErrors.join "\n"}"
    end

    # Validation errors checking for additional parameters
    @additionalErrors   = validateAdditionalLeafParams(project_id, parentID, memberOrder, noOfLeafs, conjoin,
                                                       oddMemberLeftOut)
    hasAdditionalErrors = false
    @additionalErrors.each_value do |value|
      hasAdditionalErrors = true if value.length.positive?
    end
    raise VCError, "Validation failed: #{@additionalErrors}" if hasAdditionalErrors

    # Attempt to validate ownership
    @project = Project.find(project_id)
    authorize_project! @project

    # Skip all callbacks for side creation if leafIDs and SideIDs were give in the request
    begin
      Leaf.skip_callback(:create, :before, :create_sides) if leafIDs && sideIDs
      newlyAddedLeafIDs = []
      newlyAddedLeafs   = []
      sideIDIndex       = 0
      noOfLeafs.times do |leafIDIndex|
        @leaf = Leaf.new(leaf_params)
        @leaf.id = leafIDs[leafIDIndex] if leafIDs
        @leaf.nestLevel = @group.nestLevel
        raise VCError, @leaf.errors.full_messages.join("\n") unless @leaf.save

        newlyAddedLeafs.push(@leaf)
        newlyAddedLeafIDs.push(@leaf.id.to_s)
        # Create new sides for this leaf with given SideIDs
        if leafIDs && sideIDs
          recto    = Side.new({ parentID: @leaf.id.to_s, project: @leaf.project, texture: 'Hair',
                                id: sideIDs[sideIDIndex] })
          verso    = Side.new({ parentID: @leaf.id.to_s, project: @leaf.project, texture: 'Flesh',
                                id: sideIDs[sideIDIndex + 1] })
          recto.id = "Recto_#{recto.id}"
          verso.id = "Verso_#{verso.id}"
          recto.save
          verso.save
          @leaf.rectoID = recto.id
          @leaf.versoID = verso.id
          @leaf.save
        end

        sideIDIndex += 2
      end
    rescue StandardError
    ensure
      Leaf.set_callback(:create, :before, :create_sides) if leafIDs && sideIDs
    end

    # Time to Auto-Conjoin
    autoConjoinLeaves(newlyAddedLeafs, oddMemberLeftOut) if conjoin

    # Add leaves to parent group
    @group.add_members(newlyAddedLeafIDs, memberOrder)
  end

  # PUT /leafs/generateFolio
  def generateFolio
    folioNumberCount = leaf_params_generate.to_h[:startNumber].to_i
    leafIDs          = leaf_params_generate.to_h[:leafIDs]
    leafIDs.each_with_index do |leafID, index|
      leaf = Leaf.find(leafID)
      leaf.update_attribute(:folio_number, folioNumberCount.to_s)
      folioNumberCount += 1
      @project = Project.find(leaf.project_id) if index.zero?
    end
  end

  # PATCH/PUT /leafs/1
  def update
    if leaf_params.to_h.key?(:conjoined_to)
      # HANDLE SPECIAL CASE FOR conjoined_to
      update_conjoined_partner(leaf_params.to_h[:conjoined_to])
    end
    raise VCError, "Leaf failed to update: #{@leaf.errors.full_messages.join "\n"}" unless @leaf.update(leaf_params)

    if leaf_params.to_h.key?(:attached_below) || leaf_params.to_h.key?(:attached_above)
      update_attached_to
    elsif leaf_params.to_h.key?(:material) && (leaf_params.to_h[:material] == 'Paper')
      handle_paper_update(@leaf)
    end
  end

  # PATCH/PUT /leafs
  def updateMultiple
    allLeafs = leaf_params_batch_update.to_h[:leafs]
    @project = Project.find(leaf_params_batch_update.to_h[:project_id])
    allLeafs.each do |leaf_params, _index|
      @leaf = Leaf.find(leaf_params[:id])
      authorize_project! @project
      unless @leaf.update(leaf_params[:attributes])
        raise VCError, "Leaf could not be updated: #{leaf.errors.full_messages.join "\n"}"
      end

      if leaf_params[:attributes].key?(:attached_below) || leaf_params[:attributes].key?(:attached_above)
        update_attached_to
      elsif leaf_params[:attributes].key?(:material) && (leaf_params[:attributes][:material] == 'Paper')
        handle_paper_update(@leaf)
      end
    end
  end

  # DELETE /leafs/1
  def destroy
    parent      = @project.groups.find(@leaf.parentID)
    memberOrder = parent.memberIDs.index(@leaf.id.to_s)
    # Detach its conjoined leaf
    @project.leafs.find(@leaf.conjoined_to).update(conjoined_to: nil) if @leaf.conjoined_to
    if @leaf.attached_above != 'None'
      # Detach its above attached leaf
      aboveLeaf = @project.leafs.find(parent.memberIDs[memberOrder - 1])
      aboveLeaf.update(attached_below: 'None')
    end
    if @leaf.attached_below != 'None'
      # Detach its below attached leaf
      belowLeaf = @project.leafs.find(parent.memberIDs[memberOrder + 1])
      belowLeaf.update(attached_above: 'None')
    end
    @leaf.remove_from_group
    @leaf.destroy
  end

  # DELETE /leafs.json
  def destroyMultiple
    allLeafs   = leaf_params_batch_delete.to_h[:leafs]
    project_id = Leaf.find(allLeafs[0]).project_id
    @project   = Project.find(project_id)

    parentAndChildren = {}

    allLeafs.each do |leafID|
      leaf = Leaf.find(leafID)
      @parent = @project.groups.find(leaf.parentID) if !@parent || @parent.id.to_s != leaf.parentID
      memberOrder = @parent.memberIDs.index(leaf.id.to_s)
      if leaf.project.user_id != current_user.id
        raise VCError,
              "Leaf belongs to user (#{leaf.project.user_id}) which does not match the current user's ID (#{current_user.id})"
      end

      # Detach its conjoined leaf if any
      @project.leafs.find(leaf.conjoined_to).update(conjoined_to: nil) if leaf.conjoined_to
      if leaf.attached_above != 'None'
        # Detach its above attached leaf
        aboveLeaf = @project.leafs.find(@parent.memberIDs[memberOrder - 1])
        aboveLeaf.update(attached_below: 'None')
      end
      if leaf.attached_below != 'None'
        # Detach its below attached leaf
        belowLeaf = @project.leafs.find(@parent.memberIDs[memberOrder + 1])
        belowLeaf.update(attached_above: 'None')
      end
      leaf.destroy
      # Add leaf to list of leaves to detach from parent
      if parentAndChildren[leaf.parentID].nil?
        parentAndChildren[leaf.parentID] = [leaf.id.to_s]
      else
        parentAndChildren[leaf.parentID].push(leaf.id.to_s)
      end
    end

    # Detach all leaves from parent(s)
    parentAndChildren.each do |parentID, leafIDs|
      @project.groups.find(parentID).remove_members(leafIDs)
    end
  end

  # CONJOIN /leafs.json
  def conjoinLeafs
    leafIDs = leaf_params_batch_delete.to_h[:leafs]
    leaves  = []
    # VALIDATION ERRORS
    @errors             = []
    haveErrors          = false
    allowed_project_ids = current_user.projects.pluck(:id).collect(&:to_s)
    leafIDs.each do |leafID|
      leaf = Leaf.find(leafID)
      raise VCError, 'Conjoin not allowed.' unless allowed_project_ids.include?(leaf.project_id.to_s)

      leaves.push(leaf)
    rescue Exception => e
      @errors.push("leaf not found with id #{leafID}")
      haveErrors = true
    end
    if leafIDs.size < 2
      @errors.push('Minimum of 2 leaves required to conjoin')
      haveErrors = true
    end
    raise VCError, "Error with conjoin: #{@errors.join "\n"}" if haveErrors

    @project = Project.find(leaves[0].project_id)
    autoConjoinLeaves(leaves, (leaves.length + 1) / 2)
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_leaf
    @leaf    = Leaf.find(params[:id])
    @project = Project.find(@leaf.project_id)
    authorize_project! @project
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def leaf_params
    params.require(:leaf).permit(:folio_number, :id, :project_id, :parentID, :material, :type, :conjoined_to, :stub,
                                 :attached_above, :attached_below)
  end

  def additional_params
    params.require(:additional).permit(:memberOrder, :noOfLeafs, :conjoin, :oddMemberLeftOut, leafIDs: [],
                                                                                              sideIDs: [])
  end

  def leaf_params_batch_update
    params.permit(:project_id,
                  leafs: [:id,
                          { attributes: %i[folio_number conjoined_to type material stub attached_above
                                           attached_below] }])
  end

  def leaf_params_batch_delete
    params.permit(leafs: [])
  end

  def leaf_params_conjoin
    params.permit(leafs: [])
  end

  def leaf_params_generate
    params.permit(:startNumber, leafIDs: [])
  end
end
