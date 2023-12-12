# frozen_string_literal: true

class FilterController < ApplicationController
  before_action :authenticate!
  before_action :set_project, only: [:show]

  # PUT /projects/filter
  def show
    queries = filter_params.to_h[:queries]
    errors  = runValidations(queries)
    raise VCError, "Errors: #{errors.join('\n')}" if errors != []

    @objectIDs             = { Groups: [], Leafs: [], Sides: [], Terms: [] }
    @visibleAttributes     = {
      group: { type: false, title: false },
      leaf: { type: false, material: false, conjoined_leaf_order: false, attached_below: false, attached_above: false,
              stub: false },
      side: { folio_number: false, texture: false, script_direction: false, uri: false }
    }
    combinedResult         = performFilter(queries)
    finalResponse          = buildResponse(combinedResult)
    @groups                = finalResponse[:Groups]
    @leafs                 = finalResponse[:Leafs]
    @sides                 = finalResponse[:Sides]
    @terms                 = finalResponse[:Terms]
    @groupsOfMatchingLeafs = finalResponse[:GroupsOfMatchingLeafs]
    @leafsOfMatchingSides  = finalResponse[:LeafsOfMatchingSides]
    @groupsOfMatchingSides = finalResponse[:GroupsOfMatchingSides]
    @groupsOfMatchingTerms = finalResponse[:GroupsOfMatchingTerms]
    @leafsOfMatchingTerms  = finalResponse[:LeafsOfMatchingTerms]
    @sidesOfMatchingTerms  = finalResponse[:SidesOfMatchingTerms]
    @visibleAttributes[:group] = { type: false, title: false } if @groups == []
    if @leafs == []
      @visibleAttributes[:leaf] =
        { type: false, material: false, conjoined_leaf_order: false, attached_below: false, attached_above: false,
          stub: false }
    end
    return unless @sides == []

    @visibleAttributes[:side] = { folio_number: false, texture: false, script_direction: false, uri: false }
  end

  def performFilter(queries)
    sets = []
    conjunctions = []
    queries.each do |query|
      type = query[:type]
      old_attribute = nil
      attribute = query[:attribute]
      condition = query[:condition]
      values = query[:values]
      conjunction = query[:conjunction]
      groups = []
      leafs = []
      sides = []
      terms = []

      if attribute == 'conjoined_leaf_order'
        old_attribute = attribute
        attribute = 'conjoined_to'
        values = values.map { |val| val == 'None' ? nil : val }
      end
      if attribute == 'conjoined_to'
        values = values.map { |val| val == 'None' ? nil : val }
      end

      query_condition_params = { attribute => { '$in': [] } }

      case condition
      when 'equals'
        query_condition_params = { attribute => values.length > 1 ? { '$in': values } : values[0] }
      when 'not equals'
        query_condition_params = { attribute => values.length > 1 ? { '$nin': values } : { '$ne': values[0] } }
      when 'contains'
        query_condition_params = { attribute => if values.length > 1
                                                  { '$in': values.map do |x|
                                                             /^#{Regexp.escape(x)}/
                                                           end }
                                                else
                                                  /#{Regexp.escape(values[0])}/
                                                end }
      when 'not contains'
        query_condition_params = { attribute => if values.length > 1
                                                  { '$nin': values.map do |x|
                                                              /^#{Regexp.escape(x)}/
                                                            end }
                                                else
                                                  { '$not': /#{Regexp.escape(values[0])}/ }
                                                end }
      end

      case type
      when 'group'
        groupQueryResult = @project.groups.only(:id).where(query_condition_params)
        groups = groupQueryResult.collect { |gqr| gqr.id.to_s }
        @objectIDs[:Groups] += groups
        @visibleAttributes[:group][attribute] = true if groups.length.positive?
      when 'leaf'
        leafQueryResult = @project.leafs.only(:id).where(query_condition_params)
        leafs = leafQueryResult.collect { |lqr| lqr.id.to_s }
        if leafs.length.positive?
          if old_attribute
            @visibleAttributes[:leaf][old_attribute] = true
          else
            @visibleAttributes[:leaf][attribute] = true
          end
        end
        @objectIDs[:Leafs] += leafs
      when 'side'
        sideQueryResult = @project.sides.only(:id).where(query_condition_params)
        sides = sideQueryResult.collect { |sqr| sqr.id.to_s }
        sideQueryResult.each do |sideID|
          sides.push(sideID.id.to_s)
        end
        @visibleAttributes[:side][attribute] = true if sides.length.positive?
        @objectIDs[:Sides] += sides
      when 'term'
        termQueryResult = @project.terms.only(:id).where(query_condition_params)
        terms = termQueryResult.collect { |nqr| nqr.id.to_s }
        @objectIDs[:Terms] += terms
      end
      sets.push(Set.new([*groups, *leafs, *sides, *terms]))
      conjunctions.push(conjunction)
    end
    conjunctions.pop
    result = sets[0]
    conjunctions.each_with_index do |conjunction, index|
      next unless index + 1 <= sets.length - 1

      result = if conjunction == 'AND'
                 result & sets[index + 1]
               else
                 result | sets[index + 1]
               end
    end
    result
  end

  def buildResponse(combinedResult)
    response = { Groups: [], Leafs: [], Sides: [], Terms: [], GroupsOfMatchingTerms: [], LeafsOfMatchingTerms: [],
                 SidesOfMatchingTerms: [], LeafsOfMatchingSides: [], GroupsOfMatchingSides: [], GroupsOfMatchingLeafs: [] }
    combinedResult.each do |objectID|
      if @objectIDs[:Groups].include?(objectID)
        response[:Groups].push(objectID)
      elsif @objectIDs[:Leafs].include?(objectID)
        response[:Leafs].push(objectID)
      elsif @objectIDs[:Sides].include?(objectID)
        response[:Sides].push(objectID)
      elsif @objectIDs[:Terms].include?(objectID)
        term = Term.find(objectID)
        groupIDs = term.objects[:Group]
        leafIDs = term.objects[:Leaf]
        rectoIDs = term.objects[:Recto]
        versoIDs = term.objects[:Verso]
        groupIDs.each do |groupID|
          unless response[:Groups].include?(groupID)
            response[:Groups].push(groupID)
            response[:GroupsOfMatchingTerms].push(groupID)
          end
        end
        leafIDs.each do |leafID|
          unless response[:Leafs].include?(leafID)
            response[:Leafs].push(leafID)
            response[:LeafsOfMatchingTerms].push(leafID)
          end
        end
        rectoIDs.each do |sideID|
          unless response[:Sides].include?(sideID)
            response[:Sides].push(sideID)
            response[:SidesOfMatchingTerms].push(sideID)
          end
        end
        versoIDs.each do |sideID|
          unless response[:Sides].include?(sideID)
            response[:Sides].push(sideID)
            response[:SidesOfMatchingTerms].push(sideID)
          end
        end
        response[:Terms].push(objectID)
      end
    end
    response[:Sides].each do |sideID|
      leafID = Side.find(sideID).parentID
      if !response[:LeafsOfMatchingSides].include?(leafID) && !@objectIDs[:Leafs].include?(leafID)
        response[:LeafsOfMatchingSides].push(leafID)
      end
    end
    response[:LeafsOfMatchingSides].each do |leafID|
      groupID = Leaf.find(leafID).parentID
      if !response[:GroupsOfMatchingSides].include?(groupID) && !@objectIDs[:Groups].include?(groupID)
        response[:GroupsOfMatchingSides].push(groupID)
      end
    end
    response[:Leafs].each do |leafID|
      groupID = Leaf.find(leafID).parentID
      if !response[:GroupsOfMatchingLeafs].include?(groupID) && !@objectIDs[:Groups].include?(groupID)
        response[:GroupsOfMatchingLeafs].push(groupID)
      end
    end
    response
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_project
    @project = Project.find(params[:id])
    authorize_project! @project
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def filter_params
    params.permit(queries: [:type, :attribute, :condition, :conjunction, { values: [] }])
  end
end
