# frozen_string_literal: true

FactoryGirl.define do
  sequence :term_title do |n|
    "Term #{n}"
  end
  sequence :term_text do |n|
    "Blah #{n}"
  end

  factory :term do
    transient do
      attachments { [] }
    end
    before(:build) do |_term, evaluator|
      myobjects = { Group: [], Leaf: [], Recto: [], Verso: [] }
      evaluator.attachments.each do |attachment|
        case attachment
        when Group
          myobjects[:Group] << attachment
        when Leaf
          myobjects[:Leaf] << attachment
        when Side
          if attachment.id.to_s[0..5] == 'Verso_'
            myobjects[:Verso] << attachment
          else
            myobjects[:Recto] << attachment
          end
        else
          raise Exception('Terms can only be attached to groups, leafs and sides')
        end
      end
    end

    title { generate(:term_title) }
    taxonomy { 'Unknown' }
  end
end
