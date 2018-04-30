describe TreeNode::MiqReport do
  subject { described_class.new(object, nil, {}) }
  let(:object) { FactoryGirl.create(:miq_report) }

  include_examples 'TreeNode::Node#key prefix', 'rep-'
  include_examples 'TreeNode::Node#icon', 'fa fa-file-text-o'
end
