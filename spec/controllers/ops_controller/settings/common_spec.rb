describe OpsController do
  context "OpsController::Settings::Common" do
    context "SmartProxy Affinity" do
      before do
        @zone = FactoryGirl.create(:zone, :name => 'zone1')

        @storage1 = FactoryGirl.create(:storage)
        @storage2 = FactoryGirl.create(:storage)

        @host1 = FactoryGirl.create(:host, :name => 'host1', :storages => [@storage1])
        @host2 = FactoryGirl.create(:host, :name => 'host2', :storages => [@storage2])

        @ems = FactoryGirl.create(:ext_management_system, :hosts => [@host1, @host2], :zone => @zone)

        @svr1 = FactoryGirl.create(:miq_server, :name => 'svr1', :zone => @zone)
        @svr2 = FactoryGirl.create(:miq_server, :name => 'svr2', :zone => @zone)

        @svr1.vm_scan_host_affinity = [@host1]
        @svr2.vm_scan_host_affinity = [@host2]
        @svr1.vm_scan_storage_affinity = [@storage1]
        @svr2.vm_scan_storage_affinity = [@storage2]
        allow_any_instance_of(MiqServer).to receive_messages(:is_a_proxy? => true)
        allow(MiqServer).to receive(:my_server).and_return(OpenStruct.new('id' => 0, :name => 'name'))

        tree_hash = {
          :trees       => {
            :settings_tree => {
              :active_node => "z-#{@zone.id}"
            }
          },
          :active_tree => :settings_tree,
          :active_tab  => 'settings_smartproxy_affinity'
        }
        controller.instance_variable_set(:@sb, tree_hash)
        controller.instance_variable_set(:@selected_zone, @zone)

        @temp = {}
        controller.instance_variable_set(:@temp, @temp)

        controller.send(:smartproxy_affinity_set_form_vars)
        @edit = session[:edit]
      end

      context "#smartproxy_affinity_field_changed" do
        before do
          expect(controller).to receive(:render)
        end

        it "should select a host when checked" do
          controller.params = {:id => "xx-#{@svr1.id}__host_#{@host2.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a).to include(@host2.id)
        end

        it "should deselect a host when unchecked" do
          controller.params = {:id => "xx-#{@svr1.id}__host_#{@host1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a).not_to include(@host1.id)
        end

        it "should select a datastore when checked" do
          controller.params = {:id => "xx-#{@svr1.id}__storage_#{@storage2.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a).to include(@storage2.id)
        end

        it "should deselect a datastore when unchecked" do
          controller.params = {:id => "xx-#{@svr1.id}__storage_#{@storage1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a).not_to include(@storage1.id)
        end

        it "should select all child hosts when checked" do
          controller.params = {:id => "xx-#{@svr1.id}__host", :check => '1'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a.sort).to eq([@host1.id, @host2.id])
        end

        it "should deselect all child hosts when unchecked" do
          controller.params = {:id => "xx-#{@svr1.id}__host", :check => '0'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a).to eq([])
        end

        it "should select all child datastores when checked" do
          controller.params = {:id => "xx-#{@svr1.id}__storage", :check => '1'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a.sort).to eq([@storage1.id, @storage2.id])
        end

        it "should deselect all child datastores when unchecked" do
          controller.params = {:id => "xx-#{@svr1.id}__storage", :check => '0'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a).to eq([])
        end

        it "should select all child hosts and datastores when checked" do
          controller.params = {:id => "svr-#{@svr1.id}", :check => '1'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a.sort).to eq([@host1.id, @host2.id])
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a.sort).to eq([@storage1.id, @storage2.id])
        end

        it "should deselect all child hosts and datastores when checked" do
          controller.params = {:id => "svr-#{@svr1.id}", :check => '0'}
          controller.smartproxy_affinity_field_changed
          expect(@edit[:new][:servers][@svr1.id][:hosts].to_a).to eq([])
          expect(@edit[:new][:servers][@svr1.id][:storages].to_a).to eq([])
        end
      end

      context "#smartproxy_affinity_update" do
        it "updates the SmartProxy host affinities" do
          @svr1.vm_scan_host_affinity = []
          @svr2.vm_scan_host_affinity = []

          # Commit the in-progress edit state (i.e. the initial state)
          controller.send(:smartproxy_affinity_update)
          expect(@svr1.vm_scan_host_affinity).to eq([@host1])
          expect(@svr2.vm_scan_host_affinity).to eq([@host2])
        end

        it "updates the SmartProxy storage affinities" do
          @svr1.vm_scan_storage_affinity = []
          @svr2.vm_scan_storage_affinity = []

          # Commit the in-progress edit state (i.e. the initial state)
          controller.send(:smartproxy_affinity_update)
          expect(@svr1.vm_scan_storage_affinity).to eq([@storage1])
          expect(@svr2.vm_scan_storage_affinity).to eq([@storage2])
        end
      end
    end

    context "#settings_update" do
      before do
        MiqDatabase.seed
        MiqRegion.seed
        EvmSpecHelper.local_miq_server(:zone => Zone.seed)
      end

      it "won't render form buttons after rhn settings submission" do
        session[:edit] = {
          :key => "settings_rhn_edit__rhn_edit",
          :new => {
            :register_to       => "sm_hosted",
            :customer_userid   => "username",
            :customer_password => "password",
            :server_url        => "example.com",
            :repo_name         => "example_repo_name",
            :use_proxy         => 0}}
        controller.instance_variable_set(:@_response, ActionDispatch::TestResponse.new)
        controller.instance_variable_set(:@sb, :trees       =>
                                                               {:settings_tree => {:active_node => 'root'}},
                                               :active_tree => :settings_tree,
                                               :active_tab  => 'settings_rhn_edit')
        controller.instance_variable_set(:@_params, :id => 'rhn_edit', :button => "save")
        controller.send(:settings_update)
        expect(response).to render_template('ops/_settings_rhn_tab')
        expect(response).not_to render_template(:partial => "layouts/_x_edit_buttons")
      end
    end

    context "#settings_get_form_vars" do
      before do
        miq_server = FactoryGirl.create(:miq_server)
        current = VMDB::Config.new("vmdb")
        current.config[:authentication] = {:ldap_role => true,
                                           :mode      => 'ldap'
        }
        edit = {:current => current,
                :new     => copy_hash(current.config),
                :key     => "settings_authentication_edit__#{miq_server.id}"
        }
        controller.instance_variable_set(:@edit, edit)
        session[:edit] = edit
        controller.instance_variable_set(:@sb,
                                         :selected_server_id => miq_server.id,
                                         :active_tab         => 'settings_authentication'
                                        )
        controller.x_node = "svr-#{miq_server.id}"
      end

      it "sets ldap_role to false to make forest entries div hidden" do
        controller.instance_variable_set(:@_params,
                                         :id                  => 'authentication',
                                         :authentication_mode => 'database'
                                        )
        controller.send(:settings_get_form_vars)
        expect(assigns(:edit)[:new][:authentication][:ldap_role]).to eq(false)
      end

      it "resets ldap_role to it's original state so forest entries div can be displayed" do
        session[:edit][:new][:authentication][:mode] = 'database'
        controller.instance_variable_set(:@_params,
                                         :id                  => 'authentication',
                                         :authentication_mode => 'ldap'
                                        )
        controller.send(:settings_get_form_vars)
        expect(assigns(:edit)[:new][:authentication][:ldap_role]).to eq(true)
      end
    end

    context "#update_exclude_tables_for_remote_region" do
      render_views

      before do
        EvmSpecHelper.local_miq_server(:zone => Zone.seed)
        FactoryGirl.create(:miq_region, :region => 10, :description => "The 10th region")
      end

      it "updates the exclude tables for the remote region" do
        allow(MiqRegion).to receive(:replication_type).and_return(:remote)
        allow(controller).to receive(:javascript_flash)
        params = {:replication_type => "remote", :exclusion_list => "table1", :button => "save", :id => "new"}
        controller.instance_variable_set(:@_params, params)
        controller.send(:pglogical_save_subscriptions)
        expect(assigns(:flash_array).first[:message]).to include("Replication configuration save was successful")
      end
    end

    describe '#settings_get_info' do
      before { MiqRegion.seed }

      let(:edit) { controller.instance_variable_get(:@edit) }

      context 'help menu' do
        it 'current and new in the edit hash equals' do
          controller.instance_variable_set(:@sb, :active_tab => 'settings_help_menu')
          controller.send(:settings_get_info, 'root-0')
          expect(edit[:new]).to eq(edit[:current])
        end
      end

      context 'zone node' do
        it 'sets ntp server info for display' do
          _guid, miq_server, zone = EvmSpecHelper.local_guid_miq_server_zone
          controller.instance_variable_set(:@sb, :active_tab => 'settings_zone')
          controller.instance_variable_set(:@edit, :new => {:ntp => {:server => ["1.example.com", "2.example.com"]}})
          controller.send(:zone_save_ntp_server_settings, zone)
          controller.send(:settings_get_info, "z-#{zone.id}")
          expect(assigns(:ntp_servers)).to eq("1.example.com, 2.example.com")
        end
      end
    end
  end
end
