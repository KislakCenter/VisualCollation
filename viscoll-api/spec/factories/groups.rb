# frozen_string_literal: true

FactoryGirl.define do
  sequence :quire_title do |n|
    "Quire #{n}"
  end
  sequence :booklet_title do |n|
    "Booklet #{n}"
  end
  sequence :group_title do |n|
    "Group #{n}"
  end
  factory :group, class: 'Group' do
    transient do
      members { [] }
    end
    after(:create) do |group, evaluator|
      group.nestLevel ||= 1
      if evaluator.members.present?
        newmembers = evaluator.members.each do |member|
          member.nestLevel = if member.is_a?(Group)
                               group.nestLevel + 1
                             else
                               group.nestLevel
                             end
          member.save
        end
        group.add_members(newmembers.collect { |member| member.id.to_s }, 1)
      end
      group.save
    end

    title { generate(:group_title) }
    type { 'Quire' }
  end

  factory :quire, class: 'Group' do
    transient do
      leafs { 0 }
      conjoined { true }
      leaf_properties { {} }
      start_page { 1 }
    end
    after(:create) do |group, evaluator|
      group.nestLevel ||= 1
      unless evaluator.leafs <= 0
        newleafprops = evaluator.leaf_properties.merge({
                                                         project_id: group.project_id,
                                                         parentID: group.id.to_s,
                                                         nestLevel: group.nestLevel
                                                       })
        newleafs = Array.new(evaluator.leafs) do |n|
          FactoryGirl.build(:leaf, newleafprops.merge({ folio_number: evaluator.start_page + n }))
        end
        if evaluator.conjoined
          evaluator.leafs.times.each do |n|
            unless evaluator.leafs.odd? && (n == evaluator.leafs >> 1)
              conjoin_id = newleafs[-1 - n].id.to_s
              newleafs[n].conjoined_to = conjoin_id[0..4] == 'Leaf_' ? conjoin_id : "Leaf_#{conjoin_id}"
            end
            newleafs[n].save
          end
        end
        group.add_members(newleafs.collect { |newleaf| newleaf.id.to_s }, 1)
      end
    end

    title { generate(:quire_title) }
    type { 'Quire' }
  end

  factory :booklet, parent: :quire do
    title { generate(:booklet_title) }
    type { 'Booklet' }
    leafs { 0 }
  end
end
