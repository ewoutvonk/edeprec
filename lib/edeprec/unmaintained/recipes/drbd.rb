# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

# Normal way of using this, on both hosts:
# deprec:drdb:config_gen
# <adjust anything in configs>
# deprec:drbd:install <or> deprec:drbd:config
# deprec:drbd:sync <on one host!!!>
# deprec:drbd:restart

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :drbd do
  
      set :drbd_usage_count, true
      set :drbd_resources, [
        {
          :drbd_resource => 'testing',
          :drbd_protocol => 'C',
          :drbd_disk_size => nil,
          :drbd_lvm_lv => nil,
          :drbd_lvm_vg => nil,
          :drbd_drbd1_hostname => 'drbd1',
          :drbd_drbd1_device => '/dev/drbd0',
          :drbd_drbd1_disk => '/dev/sda7',
          :drbd_drbd1_address => '172.16.0.130:7788',
          :drbd_drbd2_hostname => 'drbd2',
          :drbd_drbd2_device => '/dev/drbd0',
          :drbd_drbd2_disk => '/dev/sda7',
          :drbd_drbd2_address => '172.16.0.131:7788',
          :drbd_max_buffers => '2048',
          :drbd_ko_count => '4',
          :drbd_rate => '10M',
          :drbd_al_extents => '257',
          :drbd_wfc_timeout => '0',
          :drbd_degr_wfc_timeout => '120',
          :drbd_allow_two_primaries => true
        }
      ]

      desc "Install drbd on server"
      task :install, :roles => :storage_server do
        install_deps
        config
        reactivate
      end
  
      task :install_deps, :roles => :storage_server do
        apt.install( {:base => %w(drbd8-utils)}, :stable )
      end
  
      # The start script has a couple of config values in it.
      # We may want to extract them into a config file later
      # and install this script as part of the :install task.
      SYSTEM_CONFIG_FILES[:drbd] = [
        {:template => 'drbd.conf.erb',
         :path => '/etc/drbd.conf',
         :mode => 0644,
         :owner => 'root:root'}
      ]
  
      desc "Generate config files for drbd"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:drbd].each do |file|
          deprec2.render_template(:drbd, file)
        end
      end
  
      desc "Push drbd config files to server"
      task :config, :roles => :storage_server do
        deprec2.push_configs(:drbd, SYSTEM_CONFIG_FILES[:drbd])
        drbd_resources.each do |drbd|
          if drbd[:drbd_lvm_vg] && drbd[:drbd_lvm_lv] && drbd[:drbd_disk_size]
            sudo "sh -c '{ lvcreate -L #{drbd[:drbd_disk_size]} -n #{drbd[:drbd_lvm_lv]} #{drbd[:drbd_lvm_vg]} && { echo yes ; echo yes ; } | drbdadm create-md #{drbd[:drbd_resource]} ; } || true'"
          end
        end
        init_devices
        deprec2.append_to_file_if_missing('/etc/modules', 'drbd')
        sudo "modprobe drbd"
        sudo "drbdadm up all"
        reactivate
      end

      desc "Init devices for drbd. This will erase your data!"
      task :init_devices, :roles => :storage_server do
        drbd_resources.each do |drbd|
          # check whether we get a valid gi. If not, initialize the device.
          sudo "sh -c 'drbdadm get-gi #{drbd[:drbd_resource]} || { { echo yes ; echo yes ; } | drbdadm create-md #{drbd[:drbd_resource]} ; }'"
        end
      end
      
      desc "Sync data from one drbd device to another. Make sure you select the right one in case of existing data!"
      task :sync, :roles => :storage_server do
        drbd_resources.each do |drbd|
          sudo "drbdadm -- --overwrite-data-of-peer primary #{drbd[:drbd_resource]}"
        end
      end
    
      task :start, :roles => :storage_server do
        sudo "/etc/init.d/drbd start"
      end

      task :stop, :roles => :storage_server do
        sudo "/etc/init.d/drbd stop"
      end
  
      task :reload, :roles => :storage_server do
        sudo "drbdadm adjust all"
        make_primaries
      end
  
      task :make_primaries, :roles => :storage_server do
        drbd_resources.each do |drbd|
          if drbd[:drbd_allow_two_primaries]
            sudo "drbdadm primary #{drbd[:drbd_resource]}"
          end
        end
      end
  
      task :restart do
        stop
        start
      end

      task :activate, :roles => :storage_server do
        sudo "update-rc.d drbd start 51 S . stop 8 0 6 ."
      end
  
      task :deactivate, :roles => :storage_server do
        sudo "update-rc.d -f drbd remove"
      end
  
      task :reactivate do
        deactivate
        activate
      end
    end
  end
end