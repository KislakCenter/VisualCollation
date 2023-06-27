module ControllerHelper
  module FilterHelper

    def runValidations(queries)
      errors = []
      haveErrors = false
      if queries == []
        return ["should contain at least 1 query"]
      end
      queries.each_with_index do |query, index| 
        error = {type: "", attribute: "", condition: "", values: "", conjunction: ""}
        if (qc = query_types['type'][query['type']]).nil?
          error['type'] = "type should be one of: [#{query_types['type'].keys.join(', ')}]"
          haveErrors = true
        elsif (qc = qc[query['attribute']]).nil?
          error['attribute'] = "valid attributes for #{query['type']}: [#{query_types['type'][query['type']].keys.join(', ')}]"
          haveErrors = true
        elsif not qc.include?(query['condition'])
          error['condition'] = "valid conditions for #{query['type']} attribute #{query['attribute']} : [#{qc.join(', ')}]"
          haveErrors = true
        end

        if queries.length > 1 && index<queries.length-1 && !query_types['conjunction'].include?(query["conjunction"])
          error["conjunction"] = "conjunction should be one of : [#{query_types['conjunction'].join(', ')}]"
          haveErrors = true
        end

        if query["values"].blank?
          error["values"] = "query value cannot be empty"
          haveErrors = true
        end

        if haveErrors
          errors.push(error)
        end
      end
      return errors
    end
    
    private
    
    def query_types
      {
        'type' => {
          'group' => {
            'type' => ['equals', 'does not equal'],
            'title' => ['equals', 'does not equal', 'contains', 'does not contain']
          },
          'leaf' => {
            'type' => ['equals', 'does not equal'],
            'material' => ['equals', 'does not equal'],
            'conjoined_to' => ['equals', 'does not equal'],
            'attached_above' => ['equals', 'does not equal'],
            'attached_below' => ['equals', 'does not equal'],
            'stub' => ['equals', 'does not equal'],
            'folio_number' => ['equals', 'does not equal', 'contains', 'does not contain']
          },
          'side' => {
            'texture' => ['equals', 'does not equal'],
            'script_direction' => ['equals', 'does not equal'],
            'page_number' => ['equals', 'does not equal', 'contains', 'does not contain'],
            'uri' => ['equals', 'does not equal', 'contains', 'does not contain'],
          },
          'term' => {
            'title' => ['equals', 'does not equal', 'contains', 'does not contain'],
            'taxonomy' => ['equals', 'does not equal', 'contains', 'does not contain'],
            'description' => ['equals', 'does not equal', 'contains', 'does not contain'],
            'uri' => ['equals', 'does not equal', 'contains', 'does not contain']
          }
        },
        'conjunction' => ['OR']
      }
    end

  end
end
