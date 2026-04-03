FactoryBot.define do
  factory :task do
    title { Faker::Lorem.sentence }
    description { Faker::Lorem.paragraph }
    priority { 1 }
    status { "todo" }
    association :user
  end
end
