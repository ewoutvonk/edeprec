# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :redhat_cluster do
  
	  # check redhat cluster's cluster.conf manpage for explanation of configuring this
      set :redhat_cluster_name, 'storagecluster'
      set :redhat_cluster_config_version, '1'
      set :redhat_cluster_nodes, [
        { :name => 'clusternode1' },
        { :name => 'clusternode2' },
        { :name => 'clusternode3' },
        { :name => 'clusternode4' },
        { :name => 'clusternode5' }
      ]
      set :redhat_cluster_fence_methods, [
        { :name => 'human', :device_name => 'last_resort', :options => { :agent => 'fence_manual' } }
      ]
  
      set :redhat_cluster_exported_devices, [
        {
          :device => '/dev/sdb1', :export_name => 'assets', :gnbd_clients => '4'
        }
      ]
  
      desc "Install redhat_cluster on server (daemon)"
      task :install_server, :roles => :storage_server do
        install_deps_server
        config_server
        activate_server
      end

      desc "Install redhat_cluster on server (client)"
      task :install_client, :roles => :storage_client do
        install_deps_client
        config_client
        activate_client
      end
  
      task :install_deps_common, :roles => [:storage_client, :storage_server] do
        apt.install( {:base => %w(gfs-tools gfs2-tools cman clvm)}, :stable )
      end
  
      task :install_deps_server, :roles => :storage_server do
        install_deps_common
        apt.install( {:base => %w(gnbd-server)}, :stable )
      end
  
      task :install_deps_client, :roles => :storage_client do
        install_deps_common
        apt.install( {:base => %w(gnbd-client)}, :stable )
      end

      desc "format devices on gnbd_server"
      task :format_devices, :roles => :storage_server do
        redhat_cluster_exported_devices.each do |dev|
          sudo "gfs_mkfs -p lock_dlm -t #{redhat_cluster_name}:#{dev[:export_name]} -j #{dev[:gnbd_clients]} #{dev[:device]}"
        end
      end
  
      SYSTEM_CONFIG_FILES[:gnbd_client] = [
        {:template => 'clvm-default.erb',
         :path => '/etc/default/clvm',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'cman-default.erb',
         :path => '/etc/default/cman',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'gnbdimports.conf.erb',
         :path => '/etc/cluster/gnbdimports.conf',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'cluster.conf.erb',
         :path => '/etc/cluster/cluster.conf',
         :mode => 0644,
         :owner => 'root:root'}
      ]

      SYSTEM_CONFIG_FILES[:gnbd_server] = [
        {:template => 'clvm-default.erb',
         :path => '/etc/default/clvm',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'cman-default.erb',
         :path => '/etc/default/cman',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'gnbd-server-default.erb',
         :path => '/etc/default/gnbd-server',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'gnbdexports.conf.erb',
         :path => '/etc/cluster/gnbdexports.conf',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'cluster.conf.erb',
         :path => '/etc/cluster/cluster.conf',
         :mode => 0644,
         :owner => 'root:root'}
      ]
  
      desc "Generate config files for redhat_cluster (daemon)"
      task :config_gen_server do
        SYSTEM_CONFIG_FILES[:gnbd_server].each do |file|
          deprec2.render_template(:gnbd_server, file)
        end
      end
  
      desc "Generate config files for redhat_cluster (client)"
      task :config_gen_client do
        SYSTEM_CONFIG_FILES[:gnbd_client].each do |file|
          deprec2.render_template(:gnbd_client, file)
        end
      end
  
      task :config_common, :roles => [:storage_client, :storage_server] do
		# add some modules to load
        deprec2.append_to_file_if_missing('/etc/modules', 'dm-mod')
        deprec2.append_to_file_if_missing('/etc/modules', 'gfs')
        deprec2.append_to_file_if_missing('/etc/modules', 'lock_dlm')
        deprec2.append_to_file_if_missing('/etc/modules', 'gnbd')
		# comment out default setting of locking_type
        deprec2.substitute_in_file('/etc/lvm/lvm.conf', '^(\s*)(locking_type = 1\s*)$', '$1#$2')
        # uncomment these settings in config file
        deprec2.substitute_in_file('/etc/lvm/lvm.conf', '^(\s*)#\s*(locking_library = \"liblvm2clusterlock.so\"\s*)$', '$1$2')
        deprec2.substitute_in_file('/etc/lvm/lvm.conf', '^(\s*)#\s*(locking_type = 2\s*)$', '$1$2')
        deprec2.substitute_in_file('/etc/lvm/lvm.conf', '^(\s*)#\s*(library_dir = \"/lib/lvm2\"\s*)$', '$1$2', '%')
      end
  
      desc "Push redhat_cluster config files to server (daemon)"
      task :config_server, :roles => :storage_server do
        deprec2.push_configs(:gnbd_server, SYSTEM_CONFIG_FILES[:gnbd_server])
        config_common
        reactivate_server
      end
    
      desc "Push redhat_cluster config files to server (client)"
      task :config_client, :roles => :storage_client do
        deprec2.push_configs(:gnbd_client, SYSTEM_CONFIG_FILES[:gnbd_client])
        config_common
        reactivate_client
      end
  
      task :start_server, :roles => :storage_server do
        sudo "/etc/init.d/cman start"
        sudo "/etc/init.d/gnbd-server start"
        sudo "/etc/init.d/clvm start"
        sudo "/etc/init.d/gfs-tools start"
        sudo "/etc/init.d/gfs2-tools start"
      end

      task :start_client, :roles => :storage_client do
        sudo "/etc/init.d/cman start"
        sudo "/etc/init.d/clvm start"
        sudo "/etc/init.d/gfs-tools start"
        sudo "/etc/init.d/gfs2-tools start"
        sudo "/etc/init.d/gnbd-client start"
      end
  
      task :stop_server, :roles => :storage_server do
        sudo "/etc/init.d/gfs-tools stop"
        sudo "/etc/init.d/gfs2-tools stop"
        sudo "/etc/init.d/clvm stop"
        sudo "/etc/init.d/gnbd-server stop"
        sudo "/etc/init.d/cman stop"
      end
  
      task :stop_client, :roles => :storage_client do
        sudo "/etc/init.d/gfs-tools stop"
        sudo "/etc/init.d/gfs2-tools stop"
        sudo "/etc/init.d/gnbd-client stop"
        sudo "/etc/init.d/clvm stop"
        sudo "/etc/init.d/cman stop"
      end
  
      task :restart_server do
        stop_server
        start_server
      end

      task :restart_client do
        stop_client
        start_client
      end

      task :activate_common, :roles => [:storage_client, :storage_server] do
        sudo "update-rc.d clvm start 65 S . stop 3 0 6 ."
        sudo "update-rc.d cman start 61 S . stop 5 0 6 ."
        sudo "update-rc.d gfs-tools start 65 S . stop 2 0 6 ."
        sudo "update-rc.d gfs2-tools start 65 S . stop 2 0 6 ."
      end

      task :activate_server, :roles => :storage_server do
        sudo "update-rc.d gnbd-server start 63 S . stop 3 0 6 ."
        activate_common
      end
  
      task :activate_client, :roles => :storage_client do
        sudo "update-rc.d gnbd-client start 65 S . stop 2 0 6 ."
        activate_common
      end
  
      task :deactivate_common, :roles => [:storage_client, :storage_server] do
        sudo "update-rc.d -f clvm remove"
        sudo "update-rc.d -f cman remove"
        sudo "update-rc.d -f gfs-tools remove"
        sudo "update-rc.d -f gfs2-tools remove"
      end
  
      task :deactivate_server, :roles => :storage_server do
        sudo "update-rc.d -f gnbd-server remove"
        deactivate_common
      end
  
      task :deactivate_client, :roles => :storage_client do
        sudo "update-rc.d -f gnbd-client remove"
        deactivate_common
      end
  
      task :reactivate_server do
        deactivate_server
        activate_server
      end

      task :reactivate_client do
        deactivate_client
        activate_client
      end
    end
  end
end