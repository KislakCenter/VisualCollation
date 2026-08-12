FactoryGirl.define do
  sequence :term_title do |n|
    "Term #{n}"
  end
  sequence :term_text do |n|
    "Blah #{n}"
  end

  factory :term do
    transient do
      attachments []
    end
    after(:build) do |term, evaluator|
      term.objects ||= {Group: [], Leaf: [], Recto: [], Verso: []}
      evaluator.attachments.each do |attachment|
        attachment_id = attachment.id.to_s
        case attachment.class
        when Group
          object = Group.find(attachment_id)
          term.objects[:Group] << attachment_id
        when Leaf
          object = Leaf.find(attachment_id)
          term.objects[:Leaf] << attachment_id
        when Side
          object = Side.find(attachment_id)
          key = attachment_id.to_s.start_with?('Verso_') ? :Verso : :Recto
          term.objects[key] << attachment_id
        else
          raise Exception('Terms can only be attached to groups, leafs and sides')
        end
        object.terms << term unless object.terms.include?(term)
        object.save
      end
    end
      title { generate(:term_title) }
      taxonomy 'Unknown'
    end
  end
