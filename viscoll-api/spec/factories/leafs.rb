FactoryBot.define do
  factory :leaf do
    association "project_id",  factory: :project
    material { "Paper" }
    type { "Original" }

    factory :parchment do
      material { "Parchment" }
    end

    after(:create) do |leaf, _evaluator|
      if leaf.conjoined_to
        conjoined_leaf = Leaf.find(leaf.conjoined_to)
        conjoined_leaf.conjoined_to = leaf.id.to_s
        conjoined_leaf.save
      end
    end
  end
end
