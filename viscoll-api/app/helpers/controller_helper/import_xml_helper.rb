# frozen_string_literal: true

require 'uri'

module ControllerHelper
  module ImportXmlHelper
    # XML IMPORT
    def handleXMLImport(xml)
      @allGroupNodeIDsInOrder = []
      @allLeafNodeIDsInOrder = []
      @groups = {}
      @leafs = {}
      @rectos = {}
      @versos = {}
      @terms = {}

      # Project Information
      @projectInformation = {
        title: '',
        shelfmark: '',
        metadata: { date: '' },
        preferences: { showTips: true },
        manifests: {},
        taxonomies: ['Unknown']
      }
      # Grab project Title
      projectTitleNode = xml.xpath('//x:title', 'x' => 'http://viscoll.org/schema/collation/')
      @projectInformation[:title] = if projectTitleNode.text.empty?
                                      'No title'
                                    else
                                      projectTitleNode.text
                                    end
      @projectInformation[:title] = "XML_Import_@_#{Time.zone.now}" unless @projectInformation[:title]
      begin
        Project.find_by(title: @projectInformation[:title])
        @projectInformation[:title] = "Copy of #{@projectInformation[:title]} @ #{Time.zone.now}"
      rescue Exception => e
      end
      # grab project Shelfmark
      projectShelfmarkNode = xml.xpath('//x:shelfmark', 'x' => 'http://viscoll.org/schema/collation/')
      @projectInformation[:shelfmark] = projectShelfmarkNode.text
      # grap prohect Date
      projectDateNode = xml.xpath('//x:date', 'x' => 'http://viscoll.org/schema/collation/')
      @projectInformation[:metadata][:date] = projectDateNode.text unless projectDateNode.empty?
      # Map manifests to Project
      manifestTaxonomy = xml.xpath("//x:taxonomy[@xml:id='manifests']", 'x' => 'http://viscoll.org/schema/collation/')
      unless manifestTaxonomy.empty?
        manifestTaxonomy.children.each do |child|
          next unless child.name == 'term'

          id = child.attributes['id'].value.split('_')[-1]
          url = child.text
          @projectInformation[:manifests][id] = { id: id, url: url }
        end
      end

      # Groups Information
      allGroupNodes = xml.xpath('//x:quire', 'x' => 'http://viscoll.org/schema/collation/')
      # Generate all attributes for Groups
      allGroupNodes.each_with_index do |groupNode, index|
        groupNodeID = groupNode.attributes['id'].value
        parentNodeID = groupNode.attributes['parent']&.value
        groupOrder = index + 1
        @allGroupNodeIDsInOrder.push(groupNodeID)
        nestLevel = 1
        while parentNodeID
          nodeSearchText = "//x:quire[@xml:id='#{parentNodeID}']"
          parentGroupNode = xml.xpath(nodeSearchText, 'x' => 'http://viscoll.org/schema/collation/')
          parentNodeID = (parentGroupNode[0].attributes['parent']&.value unless parentGroupNode.empty?)
          nestLevel += 1
        end
        parentNodeID = groupNode.attributes['parent']&.value
        parentOrder = parentNodeID ? @allGroupNodeIDsInOrder.index(parentNodeID) + 1 : nil
        @groups[groupOrder] = {
          params: {
            type: 'Quire',
            title: '',
            nestLevel: nestLevel
          },
          tacketed: [],
          sewing: [],
          parentOrder: parentOrder,
          memberOrders: [],
          noteTitles: []
        }
      end
      # MAP attributes for all groups
      @groups.each do |groupOrder, _attributes|
        groupNodeID = @allGroupNodeIDsInOrder[groupOrder - 1]
        mapTargetSearchText = "//x:map[@target='##{groupNodeID}']"
        groupMappingNodes = xml.xpath(mapTargetSearchText, 'x' => 'http://viscoll.org/schema/collation/')
        next if groupMappingNodes.empty?

        groupMappingNode = groupMappingNodes[0] # Only 1 mapping per group
        groupTermTargets = groupMappingNode.children[1].attributes['target'].value.split(' ')
        groupTermTargets.each do |target|
          termSearchText = "//x:term[@xml:id='#{target[1..]}']"
          groupTerm = xml.xpath(termSearchText, 'x' => 'http://viscoll.org/schema/collation/')[0]
          groupTermTaxonomyID = groupTerm.parent.attributes['id'].value
          groupTermTaxonomyID == 'group_title' ? @groups[groupOrder][:params][:title] = groupTerm.text : nil
          groupTermTaxonomyID == 'group_type' ? @groups[groupOrder][:params][:type] = groupTerm.text : nil
          groupTermTaxonomyID == 'group_sewing' ? @groups[groupOrder][:sewing] = groupTerm.text.split(' ') : nil
          groupTermTaxonomyID == 'group_tacketed' ? @groups[groupOrder][:tacketed] = groupTerm.text.split(' ') : nil
          groupTermTaxonomyID == 'group_members' ?  @groups[groupOrder][:memberOrders] = groupTerm.text.split(' ') : nil
          if groupTermTaxonomyID == 'note_title' && !(@groups[groupOrder][:noteTitles].include? groupTerm.text)
            @groups[groupOrder][:noteTitles].push(groupTerm.text)
          end
        end
      end

      # Generate all attributes for Leafs
      allLeafNodes = xml.xpath('//x:leaf', 'x' => 'http://viscoll.org/schema/collation/')
      allLeafNodes.each_with_index do |leafNode, index|
        leafNodeID = leafNode.attributes['id'].value
        stub = leafNode.attributes['stub'] ? 'Original' : 'No'
        type = 'None'
        conjoinedToNodeID = nil
        leafOrder = index + 1
        parentNodeID = nil
        leafNode.children.each do |child|
          if child.name == 'mode'
            type = child.attributes['val'] ? child.attributes['val'].value.capitalize : 'None'
          end
          next unless child.name == 'q'

          parentNodeID = child.attributes['target']&.value
          child.children.each do |subChild|
            conjoinedToNodeID = subChild.attributes['target'].value[1..] if subChild.attributes['target']
          end
        end
        @allLeafNodeIDsInOrder.push(leafNodeID)
        nestLevel = 1
        parentOrder = 1
        if parentNodeID
          parentOrder = @allGroupNodeIDsInOrder.index(parentNodeID[1..]) + 1
          parentGroup = @groups[parentOrder]
          nestLevel = parentGroup[:params][:nestLevel]
        end
        @leafs[leafOrder] = {
          params: {
            folio_number: nil,
            material: 'None',
            type: type,
            attached_above: 'None',
            attached_below: 'None',
            stub: stub,
            nestLevel: nestLevel
          },
          conjoined_leaf_order: conjoinedToNodeID,
          parentOrder: parentOrder,
          rectoOrder: leafOrder,
          versoOrder: leafOrder,
          noteTitles: []
        }
        @rectos[leafOrder] = {
          params: {
            page_number: nil,
            texture: 'None',
            image: {},
            script_direction: 'None'
          },
          parentOrder: leafOrder,
          noteTitles: []
        }
        @versos[leafOrder] = {
          params: {
            page_number: nil,
            texture: 'None',
            image: {},
            script_direction: 'None'
          },
          parentOrder: leafOrder,
          noteTitles: []
        }
      end

      # In @groups, Update sewing, tacketed and memberOrders from nodeIDs to globalOrders
      @groups.each do |groupOrder, attributes|
        sewing = attributes[:sewing].map { |leafNodeID| @allLeafNodeIDsInOrder.index(leafNodeID[1..]) + 1 }
        tacketed = attributes[:tacketed].map { |leafNodeID| @allLeafNodeIDsInOrder.index(leafNodeID[1..]) + 1 }
        memberOrders = []
        attributes[:memberOrders].each do |memberNodeID|
          if memberNodeID.include? 'q'
            memberOrder = @allGroupNodeIDsInOrder.index(memberNodeID[1..]) + 1
            memberOrders.push("Group_#{memberOrder}")
          else
            memberOrder = @allLeafNodeIDsInOrder.index(memberNodeID[1..]) + 1
            memberOrders.push("Leaf_#{memberOrder}")
          end
        end
        @groups[groupOrder][:sewing] = sewing
        @groups[groupOrder][:tacketed] = tacketed
        @groups[groupOrder][:memberOrders] = memberOrders
      end

      # In @leafs, Update conjoined_to from nodeIDs to globalOrders.
      # Also Map material, attachment_methods (for Leaves), texture, script_direction, page_number (for Sides) and noteTitles.
      @leafs.each do |leafOrder, attributes|
        if @leafs[leafOrder][:conjoined_leaf_order]
          @leafs[leafOrder][:conjoined_leaf_order] = @allLeafNodeIDsInOrder.index(attributes[:conjoined_leaf_order]) + 1
        end
        leafNodeID = @allLeafNodeIDsInOrder[leafOrder - 1]
        mapTargetSearchText = "//x:map[@target='##{leafNodeID}']"
        leafMappingNodes = xml.xpath(mapTargetSearchText, 'x' => 'http://viscoll.org/schema/collation/')
        next if leafMappingNodes.empty?

        leafMappingNodes.each do |leafMappingNode|
          if leafMappingNode.attributes['side']
            sideTermTargets = leafMappingNode.children[1].attributes['target'].value.split(' ')
            sideTermTargets.each do |target|
              if target&.match?(URI::DEFAULT_PARSER.make_regexp)
                # This is an Image URL Map
                if leafMappingNode.attributes['side'].value == 'recto'
                  @rectos[leafOrder][:params][:image][:url] = target
                  @rectos[leafOrder][:params][:image][:label] = target.split('/')[-1]
                else
                  @versos[leafOrder][:params][:image][:url] = target
                  @versos[leafOrder][:params][:image][:label] = target.split('/')[-1]
                end
              elsif target[1..] == 'manifest_DIYImages'
                if leafMappingNode.attributes['side'].value == 'recto'
                  @rectos[leafOrder][:params][:image][:manifestID] = 'DIYImages'
                  @rectos[leafOrder][:params][:image][:label] =
                    @rectos[leafOrder][:params][:image][:label].split('_', 2)[1]
                else
                  @versos[leafOrder][:params][:image][:manifestID] = 'DIYImages'
                  @versos[leafOrder][:params][:image][:label] =
                    @versos[leafOrder][:params][:image][:label].split('_', 2)[1]
                end
              else
                termSearchText = "//x:term[@xml:id='#{target[1..]}']"
                sideTerms = xml.xpath(termSearchText, 'x' => 'http://viscoll.org/schema/collation/')
                unless sideTerms.empty?
                  sideTerm = sideTerms[0]
                  sideTermTaxonomyID = sideTerm.parent.attributes['id'].value
                  if leafMappingNode.attributes['side'].value == 'recto'
                    sideTermTaxonomyID == 'side_texture' ? @rectos[leafOrder][:params][:texture] = sideTerm.text : nil
                    if sideTermTaxonomyID == 'side_script_direction'
                      @rectos[leafOrder][:params][:script_direction] =
                        sideTerm.text
                    end
                    if sideTermTaxonomyID == 'side_page_number'
                      @rectos[leafOrder][:params][:page_number] =
                        sideTerm.text
                    end
                    if sideTermTaxonomyID == 'manifests'
                      @rectos[leafOrder][:params][:image][:manifestID] =
                        sideTerm.attributes['id'].value.split('_')[1]
                    end
                    if sideTermTaxonomyID == 'note_title' && !(@rectos[leafOrder][:noteTitles].include? sideTerm.text)
                      @rectos[leafOrder][:noteTitles].push(sideTerm.text)
                    end
                  else
                    sideTermTaxonomyID == 'side_texture' ? @versos[leafOrder][:params][:texture] = sideTerm.text : nil
                    if sideTermTaxonomyID == 'side_script_direction'
                      @versos[leafOrder][:params][:script_direction] =
                        sideTerm.text
                    end
                    if sideTermTaxonomyID == 'side_page_number'
                      @versos[leafOrder][:params][:page_number] =
                        sideTerm.text
                    end
                    if sideTermTaxonomyID == 'manifests'
                      @versos[leafOrder][:params][:image][:manifestID] =
                        sideTerm.attributes['id'].value.split('_')[1]
                    end
                    if sideTermTaxonomyID == 'note_title' && !(@versos[leafOrder][:noteTitles].include? sideTerm.text)
                      @versos[leafOrder][:noteTitles].push(sideTerm.text)
                    end
                  end
                end
              end
            end
          else
            leafTermTargets = leafMappingNode.children[1].attributes['target'].value.split(' ')
            leafTermTargets.each do |target|
              termSearchText = "//x:term[@xml:id='#{target[1..]}']"
              leafTerms = xml.xpath(termSearchText, 'x' => 'http://viscoll.org/schema/collation/')
              next if leafTerms.empty?

              leafTerm = leafTerms[0]
              leafTermTaxonomyID = leafTerm.parent.attributes['id'].value
              leafTermTaxonomyID == 'leaf_material' ? @leafs[leafOrder][:params][:material] = leafTerm.text : nil
              if leafTermTaxonomyID == 'note_title' && !(@leafs[leafOrder][:noteTitles].include? leafTerm.text)
                @leafs[leafOrder][:noteTitles].push(leafTerm.text)
              end
              next unless leafTermTaxonomyID == 'leaf_attachment_method'

              if leafTerm.attributes['id'].value.include?('Above')
                @leafs[leafOrder][:params][:attached_above] =
                  leafTerm.text
              end
              if leafTerm.attributes['id'].value.include?('Below')
                @leafs[leafOrder][:params][:attached_below] =
                  leafTerm.text
              end
            end
          end
        end
      end

      # Everything is fine upto this point unless the xml import is driectly from Dot's Model.
      # In that case, we have to generate the memberOrders attribute for each Group manually.
      # We will loose the actual memberOrders. Here we add the Group members first and then Leaf members.
      taxonomySearchText = "//x:taxonomy[@xml:id='group_members']"
      groupMembersTermNodes = xml.xpath(taxonomySearchText, 'x' => 'http://viscoll.org/schema/collation/')
      if groupMembersTermNodes.empty?
        # Need to handle adding members to Groups
        @groups.each do |groupOrder, attributes|
          @groups[attributes[:parentOrder]][:memberOrders].push("Group_#{groupOrder}") if attributes[:parentOrder]
        end
        @leafs.each do |leafOrder, attributes|
          @groups[attributes[:parentOrder]][:memberOrders].push("Leaf_#{leafOrder}") if attributes[:parentOrder]
        end
      end

      jsonImport = {
        project: @projectInformation,
        Groups: @groups,
        Leafs: @leafs,
        Rectos: @rectos,
        Versos: @versos,
        Terms: @terms
      }

      handleJSONImport(JSON.parse(jsonImport.to_json))
    end
  end
end
