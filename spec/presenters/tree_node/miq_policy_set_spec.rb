describe TreeNode::MiqPolicySet do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_policy_set, :name => 'Just a set') }

  include_examples 'TreeNode::Node#key prefix', 'pp-'
  include_examples 'TreeNode::Node#text description'
  include_examples 'TreeNode::Node#icon', 'fa fa-inactive fa-shield'
end
