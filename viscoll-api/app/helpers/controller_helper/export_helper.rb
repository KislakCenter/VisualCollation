# frozen_string_literal: true

require 'erb'

module ControllerHelper
  module ExportHelper
    IMAGE_LIST_ERB = File.expand_path 'image_list.xml.erb', __dir__

    def buildJSON(_project)
      @project.reload
      @projectInformation = {}
      @groupIDs           = @project.groupIDs
      @leafIDs            = []
      @rectoIDs           = []
      @versoIDs           = []
      @groups             = {}
      @leafs              = {}
      @rectos             = {}
      @versos             = {}
      @terms              = {}

      @projectInformation = {
        "title": @project.title,
        "shelfmark": @project.shelfmark,
        "notationStyle": @project.notationStyle,
        "metadata": @project.metadata,
        "preferences": @project.preferences,
        "manifests": @project.manifests,
        "taxonomies": @project.taxonomies
      }

      rootMemberOrder = 1
      @groupIDs.each_with_index do |groupID, index|
        group              = @project.groups.find(groupID)
        @groups[index + 1] = {
          "params": {
            "type": group.type,
            "title": group.title,
            "nestLevel": group.nestLevel
          },
          "tacketed": group.tacketed,
          "sewing": group.sewing,
          "parentOrder": group.parentID,
          "memberOrders": group.memberIDs
        }
        rootMemberOrder += 1 if group.nestLevel == 1
      end

      # Generate @leafIDs list
      @groups.each do |_groupOrder, group|
        getLeafMemberOrders(group[:memberOrders]) if group[:params][:nestLevel] == 1
      end

      @leafIDs.each_with_index do |leafID, index|
        leaf              = @project.leafs.find(leafID)
        @leafs[index + 1] = {
          "params": {
            "folio_number": leaf.folio_number || '',
            "material": leaf.material,
            "type": leaf.type,
            "attached_above": leaf.attached_above,
            "attached_below": leaf.attached_below,
            "stub": leaf.stub,
            "nestLevel": leaf.nestLevel
          },
          "conjoined_leaf_order": leaf.conjoined_to ? @leafIDs.index(leaf.conjoined_to) + 1 : nil,
          "parentOrder": @groupIDs.index(leaf.parentID) + 1,
          "rectoOrder": index + 1,
          "versoOrder": index + 1
        }
        @rectoIDs.push(leaf.rectoID)
        @versoIDs.push(leaf.versoID)
      end

      # Transform group's members to global orders
      # Transform group's tacketed and sewing to leaf global orders
      # Transform group's parentID to group global order
      @groups.each do |_groupID, group|
        memberOrders = []
        group[:memberOrders].each do |memberID|
          if memberID[0] == 'G'
            memberOrders.push("Group_#{@groupIDs.index(memberID) + 1}")
          else
            memberOrders.push("Leaf_#{@leafIDs.index(memberID) + 1}")
          end
        end
        group[:memberOrders] = memberOrders
        tacketedLeafOrders = []
        sewingLeafOrders = []
        group[:tacketed].each do |leafID|
          tacketedLeafOrders.push(@leafIDs.index(leafID) + 1)
        end
        group[:sewing].each do |leafID|
          sewingLeafOrders.push(@leafIDs.index(leafID) + 1)
        end
        group[:tacketed] = tacketedLeafOrders
        group[:sewing] = sewingLeafOrders
        group[:parentOrder] = group[:parentOrder] ? @groupIDs.index(group[:parentOrder]) + 1 : nil
      end

      @rectoIDs.each_with_index do |rectoID, index|
        recto              = @project.sides.find(rectoID)
        parentOrder        = @leafIDs.index(recto.parentID) + 1
        @rectos[index + 1] = {
          "params": {
            "page_number": recto.page_number || '',
            "texture": recto.texture,
            "image": recto.image,
            "script_direction": recto.script_direction
          },
          "parentOrder": parentOrder
        }
      end

      @versoIDs.each_with_index do |versoID, index|
        verso              = @project.sides.find(versoID)
        parentOrder        = @leafIDs.index(verso.parentID) + 1
        @versos[index + 1] = {
          "params": {
            "page_number": verso.page_number || '',
            "texture": verso.texture,
            "image": verso.image,
            "script_direction": verso.script_direction
          },
          "parentOrder": parentOrder
        }
      end

      @project.terms.each_with_index do |term, index|
        @terms[index + 1] = {
          "params": {
            "title": term.title,
            "taxonomy": term.taxonomy,
            "description": term.description,
            "show": term.show
          },
          "objects": {}
        }
        @terms[index + 1][:params][:uri] = term.uri if term.uri.present?

        @terms[index + 1][:objects][:Group] = term.objects['Group'].map { |groupID| @groupIDs.index(groupID) + 1 }
        @terms[index + 1][:objects][:Leaf]  = term.objects['Leaf'].map { |leafID| @leafIDs.index(leafID) + 1 }
        @terms[index + 1][:objects][:Recto] = term.objects['Recto'].map { |rectoID| @rectoIDs.index(rectoID) + 1 }
        @terms[index + 1][:objects][:Verso] = term.objects['Verso'].map { |versoID| @versoIDs.index(versoID) + 1 }
      end

      {
        "project": @projectInformation,
        "groups": @groups,
        "leafs": @leafs,
        "rectos": @rectos,
        "versos": @versos,
        "terms": @terms
      }
    end

    # Populate leaf orders recursively
    def getLeafMemberOrders(memberIDs)
      memberIDs.each_with_index do |memberID, _index|
        if memberID[0] == 'G'
          getLeafMemberOrders(@groups[@groupIDs.index(memberID) + 1][:memberOrders])
        elsif memberID[0] == 'L'
          @leafIDs.push(memberID)
        end
      end
    end

    def findSideParents(hash, key, side)
      id_list = hash[key]
      return [] if id_list.nil?

      side_IDs = id_list.select { |i| i[0] == side[0] }
      side_IDs.map { |s| Side.find(s).parentID }
    end

    def findNonSides(hash, key)
      id_list = hash[key]
      return [] if id_list.nil?

      sides = %w[R V]
      id_list.reject { |i| sides.include? i[0] }
    end

    def buildDotModel(project)
      @groupIDs                = project.groupIDs
      @groups                  = {}
      @leafIDs                 = []
      @leafs                   = {}
      @rectos                  = {}
      @versos                  = {}
      @terms                   = {}
      @termTitles              = []
      @allGroupAttributeValues = []
      @allLeafAttributeValues  = []
      @allSideAttributeValues  = []
      @groupIDs.each_with_index do |groupID, index|
        if @groups.key?(groupID)
          memberOrder                    = @groups[groupID][:memberOrder]
          @groups[groupID]               = project.groups.find(groupID)
          @groups[groupID][:memberOrder] = memberOrder
        else
          @groups[groupID]               = project.groups.find(groupID)
          @groups[groupID][:memberOrder] = index + 1
        end
        populateLeafSideObjects(@groups[groupID][:memberIDs], project) if @groups[groupID][:memberIDs]
      end

      schema_xml = Nokogiri::XML File.open('public/viscoll-datamodel2.0.rng')
      schema_xml.remove_namespaces!
      path = <<~X
        /grammar/start/element[@name = "viscoll"]/optional/attribute[@name="version"]/choice/value/text()
      X
      version = schema_xml.xpath path

      Nokogiri::XML::Builder.new { |xml|
        xml.viscoll xmlns: 'http://viscoll.org/schema/collation/', version: version do
          idPrefix = project.shelfmark.parameterize.underscore

          # STRUCTURE
          xml.textblock do
            xml.title project.title
            xml.shelfmark project.shelfmark
            xml.date project.metadata[:date]
            xml.direction val: 'l-r'
            idPrefix = project.shelfmark.parameterize.underscore
            xml.quires do
              @groupIDs.each_with_index do |groupID, _index|
                group = @groups[groupID]
                next if group.parentID.present?

                quireAttributes             = {}
                quireAttributes['xml:id']   = group.id
                quireAttributes[:n]         = group.group_notation
                quireAttributes[:certainty] = 1
                quireAttributes[:parent] = group.parentID if group.parentID
                xml.quire quireAttributes do
                  # xml.text index + 1
                  # TODO: loop though quire's subquires
                end
                @groups[groupID]['xmlID'] = quireAttributes['xml:id']
              end
            end
            xml.leaves do
              @leafIDs.each_with_index do |leafID, _index|
                leaf                     = project.leafs.find(leafID)
                leafAttributes           = {}
                leafAttributes['xml:id'] = leaf.id
                leafAttributes['stub']   = 'yes' if leaf.stubType != 'No'
                xml.leaf leafAttributes do
                  # if leaf.folio_number
                  #   folioNumberAttr = {}
                  #   folioNumberAttr[:certainty] = 1
                  #   folioNumber = leaf.folio_number
                  #   folioNumberAttr[:val] = folioNumber
                  #   xml.folioNumber folioNumberAttr do
                  #     xml.text folioNumber
                  #   end
                  # elsif rectoSide.page_number && leaf.folio_number.nil?
                  #   pageNumberAttr = {}
                  #   pageNumberAttr[:certainty] = 1
                  #   pageNumber = "#{rectoSide.page_number.to_s}-#{versoSide.page_number.to_s}"
                  #   pageNumberAttr[:val] = pageNumber
                  #   xml.folioNumber pageNumberAttr do
                  #     xml.text pageNumber
                  #   end
                  # end

                  # get side objects
                  rectoSide = project.sides.find(leaf.rectoID)
                  versoSide = project.sides.find(leaf.versoID)

                  # generate page notation
                  numbers    = []
                  numbers[0] = leaf.folio_number
                  pages      = [rectoSide.page_number, versoSide.page_number]
                  pages.compact!
                  page_number  = pages.empty? ? nil : pages.join('-')
                  numbers[1]   = page_number
                  pageNotation = nil
                  pageNotation = numbers.empty? ? nil : numbers.compact.join('; ')

                  unless pageNotation.empty?
                    # folioNumber element
                    folioNumberAttr             = {}
                    folioNumberAttr[:certainty] = 1
                    folioNumberAttr[:val]       = pageNotation
                    xml.folioNumber folioNumberAttr do
                      xml.text pageNotation
                    end
                  end

                  mode = {}
                  if %w[original added replaced false missing].include? leaf.type.downcase
                    mode[:val]       = leaf.type.downcase
                    mode[:certainty] = 1
                  end
                  xml.mode mode

                  # TODO: come up with consistent way of caching and assigning xml IDs
                  qAttributes             = {}
                  qAttributes[:target]    = "##{leaf.parentID}"
                  qAttributes[:position]  = leaf.position_in_top_level_group
                  qAttributes[:n]         = project.groups.find(leaf.parentID).group_notation
                  qAttributes[:certainty] = 1
                  xml.q qAttributes do
                    if leaf.conjoined_to
                      xml.conjoin certainty: 1, target: "##{leaf.conjoined_to}"
                    else
                      xml.single val: 'yes'
                    end
                  end

                  # <attachment-method certainty="1" type="pasted" target="#id-Ferr208-1-7"/>
                  attachmentAttributes             = {}
                  attachmentAttributes[:certainty] = 1

                  if leaf.attached_above != 'None'
                    attachmentAttributes[:type]   = leaf.attached_above.downcase
                    attachmentAttributes[:target] = "##{@leafIDs[@leafIDs.index(leaf.id) - 1]}"
                    xml.send('attachment-method', attachmentAttributes)
                  end

                  if leaf.attached_below != 'None'
                    attachmentAttributes[:type]   = leaf.attached_below.downcase
                    attachmentAttributes[:target] = "##{@leafIDs[@leafIDs.index(leaf.id) + 1]}"
                    xml.send('attachment-method', attachmentAttributes)
                  end

                  rectoSide                 = project.sides.find(leaf.rectoID)
                  rectoAttributes           = {}
                  rectoAttributes['xml:id'] = leafAttributes['xml:id']
                  rectoAttributes[:type]    = 'Recto'
                  rectoAttributes[:page_number] = (rectoSide.page_number || 'EMPTY')
                  rectoAttributes[:texture]          = rectoSide.texture unless rectoSide.texture == 'None'
                  unless rectoSide.script_direction == 'None'
                    rectoAttributes[:script_direction] =
                      rectoSide.script_direction
                  end
                  rectoAttributes[:image]            = rectoSide.image[:url] unless rectoSide.image.empty?
                  rectoAttributes[:target]           = "##{leafAttributes['xml:id']}"
                  # xml.side rectoAttributes
                  @rectos[leaf.rectoID]          = rectoAttributes
                  @rectos[leaf.rectoID]['recto'] = rectoSide
                  versoSide                      = project.sides.find(leaf.versoID)
                  versoAttributes                = {}
                  versoAttributes['xml:id']      = leafAttributes['xml:id']
                  versoAttributes[:type]         = 'Verso'
                  versoAttributes[:page_number] = (versoSide.page_number || 'EMPTY')
                  versoAttributes[:texture]          = versoSide.texture unless versoSide.texture == 'None'
                  unless versoSide.script_direction == 'None'
                    versoAttributes[:script_direction] =
                      versoSide.script_direction
                  end
                  versoAttributes[:image]            = versoSide.image[:url] unless versoSide.image.empty?
                  versoAttributes[:target]           = "##{leafAttributes['xml:id']}"
                  # xml.side versoAttributes
                  @versos[leaf.versoID]          = versoAttributes
                  @versos[leaf.versoID]['verso'] = versoSide
                end
                @leafs[leafID]['xmlID'] = leafAttributes['xml:id']
              end
            end
          end

          # Hard-coded parchment sides taxonomy
          parch_att = { 'xml:id': 'id-sides', ref: 'http://w3id.org/lob/' }
          xml.taxonomy parch_att do
            xml.label do
              xml.text 'Parchment Sides'
            end
            hs_attributes = { 'xml:id': 'id-hs', ref: 'http://w3id.org/lob/concept/1381' }
            xml.term hs_attributes do
              xml.label do
                xml.text 'hairside'
              end
            end
            fs_attributes = { 'xml:id': 'id-fs', ref: 'http://w3id.org/lob/concept/1336' }
            xml.term fs_attributes do
              xml.label do
                xml.text 'fleshside'
              end
            end
            left_attributes = { 'xml:id': 'id-left', ref: 'http://w3id.org/lob/concept/2947' }
            xml.term left_attributes do
              xml.label do
                xml.text 'left'
              end
            end
            right_attributes = { 'xml:id': 'id-right', ref: 'http://w3id.org/lob/concept/3004' }
            xml.term right_attributes do
              xml.label do
                xml.text 'right'
              end
            end
          end

          # terms taxonomy
          if project.terms.present?
            terms_att = { 'xml:id': 'id-terms' }
            xml.taxonomy terms_att do
              xml.label do
                xml.text 'List of all Terms'
              end
              project.terms.each do |term|
                term_att = { 'xml:id': term.id.to_s }
                xml.term term_att do
                  xml.label do
                    xml.text term.title
                  end
                end
              end
            end
          end

          # Creating taxonomy elements
          project.taxonomies.each do |taxonomy|
            require 'digest'
            taxAtt = { 'xml:id': "id-#{Digest::MD5.hexdigest(taxonomy)}" }
            # grab an array of terms with the current taxonomy
            children = project.terms.select { |term| term.taxonomy == taxonomy }
            next if children.blank?

            xml.taxonomy taxAtt do
              xml.label do
                xml.text taxonomy
              end
              # add proper attributes and crete term elements
              children.each do |childTerm|
                termAttributes = { 'xml:id': childTerm.id.to_s }
                termAttributes['ref'] = childTerm.uri if childTerm.uri.present?
                xml.term termAttributes do
                  xml.label do
                    xml.text childTerm.title
                  end
                end
              end
            end
          end

          # check if any mappings exist
          if project.mapping?
            mappings_hash = {}
            project.mappings.each do |mapping|
              mappings_hash[mapping.keys.first] ||= []
              mappings_hash[mapping.keys.first] << mapping[mapping.keys.first]
            end
            # MAPPING
            xml.mapping do
              mappings_hash.each_key do |k|
                xml_id = case k
                         when 'Hair'
                           'id-hs'
                         when 'Flesh'
                           'id-fs'
                         else
                           k
                         end
                term_recto_parents = findSideParents mappings_hash, k, 'R'
                if term_recto_parents.present?
                  term_recto_att = { target: term_recto_parents.map { |m|
                                               "##{m}"
                                             }.join(' '), side: project.recto_side }
                  xml.map term_recto_att do
                    xml.term target: "##{xml_id}"
                  end
                end

                term_verso_parents = findSideParents mappings_hash, k, 'V'
                if term_verso_parents.present?
                  term_verso_att = { target: term_verso_parents.map { |m|
                                               "##{m}"
                                             }.join(' '), side: project.verso_side }
                  xml.map term_verso_att do
                    xml.term target: "##{xml_id}"
                  end
                end

                non_side_IDs = findNonSides mappings_hash, k
                next if non_side_IDs.blank?

                non_side_att = { target: non_side_IDs.map { |m| "##{m}" }.join(' ') }
                xml.map non_side_att do
                  xml.term target: "##{xml_id}"
                end
              end
            end
          end
        end
      }.to_xml
    end

    # Populate leaf and side objects in ascending order
    def populateLeafSideObjects(memberIDs, project, leafMember = 1)
      groupMember = 1
      memberIDs.each_with_index do |memberID, _index|
        if memberID[0] == 'G'
          @groups[memberID] = { "memberOrder": groupMember }
          populateLeafSideObjects(project.groups.find(memberID).memberIDs, project, leafMember)
          groupMember += 1
        elsif memberID[0] == 'L'
          unless @leafIDs.include? memberID
            leaf = project.leafs.find(memberID)
            @leafIDs.push(memberID)
            @leafs[memberID]                = leaf
            @leafs[memberID]['memberOrder'] = leafMember
            @rectos[leaf.rectoID]           = project.sides.find(leaf.rectoID)
            @versos[leaf.versoID]           = project.sides.find(leaf.versoID)
            leafMember += 1
          end
        end
      end
    end

    # Get all parent orders upto root
    def parentsOrders(memberID, project)
      result = []
      if memberID
        result = if memberID[0] == 'G'
                   parentsOrders(project.groups.find(memberID).parentID,
                                 project) + [(@groupIDs.index(memberID) + 1).to_s]
                 else
                   parentsOrders(project.leafs.find(memberID).parentID, project) + [@leafs[memberID][:memberOrder].to_s]
                 end
      end
      result
    end

    def build_image_list(project)
      erb        = ERB.new open(IMAGE_LIST_ERB).read
      erb.result binding
    end
  end
end
