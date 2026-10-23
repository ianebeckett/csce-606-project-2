require "rails_helper"

RSpec.describe TopicPrerequisite do
  let!(:first) { Topic.create!(name: "First", position: 0) }
  let!(:second) { Topic.create!(name: "Second", position: 1) }
  let!(:third) { Topic.create!(name: "Third", position: 2) }

  it "requires both topics and rejects duplicate links in the model and database" do
    expect(described_class.new).not_to be_valid
    link = described_class.create!(topic: second, prerequisite_topic: first)
    expect(link.dup).not_to be_valid
    expect { link.dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "rejects self prerequisites in the model and database" do
    link = described_class.new(topic: first, prerequisite_topic: first)
    expect(link).not_to be_valid
    expect { link.save!(validate: false) }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "rejects direct and transitive cycles" do
    described_class.create!(topic: second, prerequisite_topic: first)
    described_class.create!(topic: third, prerequisite_topic: second)

    [ second, third ].each do |prerequisite|
      link = described_class.new(topic: first, prerequisite_topic: prerequisite)
      expect(link).not_to be_valid
      expect(link.errors[:prerequisite_topic]).to include("cannot create a cycle")
    end
  end

  it "allows shared prerequisites and validates changes without counting the old link" do
    link = described_class.create!(topic: second, prerequisite_topic: first)
    described_class.create!(topic: third, prerequisite_topic: first)
    described_class.create!(topic: third, prerequisite_topic: second)
    expect(link).to be_valid
    expect(link.update(prerequisite_topic: third)).to be(false)
    link.reload
    expect(link.update(topic: first, prerequisite_topic: second)).to be(true)
  end

  it "removes incoming and outgoing links when an empty topic is deleted" do
    described_class.create!(topic: second, prerequisite_topic: first)
    described_class.create!(topic: third, prerequisite_topic: second)
    expect { second.destroy! }.to change(described_class, :count).by(-2)
  end
end
