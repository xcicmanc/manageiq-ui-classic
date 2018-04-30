describe SecurityGroupController do
  include_examples :shared_examples_for_security_group_controller, %w(openstack azure google amazon)

  context "#tags_edit" do
    let!(:user) { stub_user(:features => :all) }
    before(:each) do
      EvmSpecHelper.create_guid_miq_server_zone
      @ct = FactoryGirl.create(:security_group, :name => "security-group-01")
      allow(@ct).to receive(:tagged_with).with(:cat => user.userid).and_return("my tags")
      classification = FactoryGirl.create(:classification, :name => "department", :description => "Department")
      @tag1 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag1",
                                 :parent => classification)
      @tag2 = FactoryGirl.create(:classification_tag,
                                 :name   => "tag2",
                                 :parent => classification)
      allow(Classification).to receive(:find_assigned_entries).with(@ct).and_return([@tag1, @tag2])
      session[:tag_db] = "SecurityGroup"
      edit = {
        :key        => "SecurityGroup_edit_tags__#{@ct.id}",
        :tagging    => "SecurityGroup",
        :object_ids => [@ct.id],
        :current    => {:assignments => []},
        :new        => {:assignments => [@tag1.id, @tag2.id]}
      }
      session[:edit] = edit
    end

    after(:each) do
      expect(response.status).to eq(200)
    end

    it "builds tagging screen" do
      post :button, :params => { :pressed => "security_group_tag", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array)).to be_nil
    end

    it "cancels tags edit" do
      session[:breadcrumbs] = [{:url => "security_group/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "cancel", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("was cancelled by the user")
      expect(assigns(:edit)).to be_nil
    end

    it "save tags" do
      session[:breadcrumbs] = [{:url => "security_group/show/#{@ct.id}"}, 'placeholder']
      post :tagging_edit, :params => { :button => "save", :format => :js, :id => @ct.id }
      expect(assigns(:flash_array).first[:message]).to include("Tag edits were successfully saved")
      expect(assigns(:edit)).to be_nil
    end
  end

  describe "#show" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @security_group = FactoryGirl.create(:security_group_with_firewall_rules)
      login_as FactoryGirl.create(:user)
    end

    subject do
      get :show, :params => {:id => @security_group.id}
    end

    context "render" do
      render_views
      it do
        is_expected.to have_http_status 200
        is_expected.to render_template(:partial => 'layouts/_textual_groups_generic')
        is_expected.to render_template(:partial => "layouts/listnav/_security_group")
      end
    end
  end

  describe "#create" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @security_group = FactoryGirl.create(:security_group_openstack)
    end

    context "#create" do
      let(:task_options) do
        {
          :action => "creating Security Group for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @ems.class.name,
          :method_name => 'create_security_group',
          :instance_id => @ems.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => [{:name => "test"}]
        }
      end

      it "builds create screen" do
        post :button, :params => { :pressed => "security_group_new", :format => :js }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the create action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :create, :params => { :button => "add", :format => :js, :name => 'test',
                                   :tenant_id => 'id', :ems_id => @ems.id }
      end
    end
  end

  describe "#edit" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @security_group = FactoryGirl.create(:security_group_with_firewall_rules_openstack, :ext_management_system => @ems)
    end

    context "#edit" do
      let(:security_group_task_options) do
        {
          :action => "updating Security Group for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:security_group_queue_options) do
        {
          :class_name  => @security_group.class.name,
          :method_name => 'raw_update_security_group',
          :instance_id => @security_group.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => [{:name => "foo2", :description => "New desc"}]
        }
      end
      let(:firewall_rule_task_options) do
        {
          :action => "create Security Group rule for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:firewall_rule_queue_options) do
        {
          :class_name  => @security_group.class.name,
          :method_name => 'raw_create_security_group_rule',
          :instance_id => @security_group.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => [@security_group.ems_ref, "outbound", { :ethertype => "", :port_range_min => nil,
             :port_range_max => nil, :protocol => "tcp", :remote_group_id => nil, :remote_ip_prefix => nil }]
        }
      end

      it "builds edit screen" do
        post :button, :params => { :pressed => "security_group_edit", :format => :js, :id => @security_group.id }
        expect(assigns(:flash_array)).to be_nil
      end

      it "queues the update action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(security_group_task_options, security_group_queue_options)
        expect(MiqTask).to receive(:generic_action_with_callback).with(firewall_rule_task_options, firewall_rule_queue_options)
        post :update, :params => { :button => "save", :format => :js, :id => @security_group.id, :name => "foo2",
          :description => "New desc",
          "firewall_rules" => { "0" => { "id" => "", "host_protocol" => "TCP", "direction" => "outbound" }}}
      end
    end
  end

  describe "#delete" do
    before do
      stub_user(:features => :all)
      EvmSpecHelper.create_guid_miq_server_zone
      @ems = FactoryGirl.create(:ems_openstack).network_manager
      @security_group = FactoryGirl.create(:security_group_openstack, :ext_management_system => @ems)
    end

    context "#delete" do
      let(:task_options) do
        {
          :action => "deleting Security Group for user %{user}" % {:user => controller.current_user.userid},
          :userid => controller.current_user.userid
        }
      end
      let(:queue_options) do
        {
          :class_name  => @security_group.class.name,
          :method_name => 'raw_delete_security_group',
          :instance_id => @security_group.id,
          :priority    => MiqQueue::HIGH_PRIORITY,
          :role        => 'ems_operations',
          :zone        => @ems.my_zone,
          :args        => []
        }
      end

      it "queues the delete action" do
        expect(MiqTask).to receive(:generic_action_with_callback).with(task_options, queue_options)
        post :button, :params => { :id => @security_group.id, :pressed => "security_group_delete", :format => :js }
      end
    end
  end

  describe '#button' do
    before do
      controller.instance_variable_set(:@_params, params)
    end

    context 'tagging instances from their list, accessed from the details page of a security group' do
      let(:params) { {:pressed => "instance_tag"} }

      it 'calls tag method for tagging instances' do
        expect(controller).to receive(:tag).with("VmOrTemplate")
        controller.send(:button)
      end
    end

    context 'tagging network ports from their list, accessed from the details page of a security group' do
      let(:params) { {:pressed => "network_port_tag"} }

      it 'calls tag method for tagging network ports' do
        expect(controller).to receive(:tag).with("NetworkPort")
        controller.send(:button)
      end
    end
  end
end
