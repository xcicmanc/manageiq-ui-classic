describe TreeNode::MiqAeInstance do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_ae_instance) }

  include_examples 'TreeNode::Node#key prefix', 'aei-'
  include_examples 'TreeNode::Node#icon', 'fa fa-file-text-o'
  include_examples 'TreeNode::Node#tooltip prefix', 'Automate Instance'
end
