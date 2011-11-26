# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :keepalived do

      set :keepalived_default_script_weight, 2
      set :keepalived_default_script_interval, 1
      # the two variables below default to the values above
      set :keepalived_chk_wanted_state_weight, nil
      set :keepalived_chk_wanted_state_interval, nil

      # :keepalived_scripts should contain a hash where each key is the suffix of the vrrp_script registration,
      # and the value is again a hash, containing as key => value pairs:
      # :script => 'killall -0 haproxy' or any script which returns a 0 or 1 exit value
      # :interval => 1
      # :weight => 2
      set :keepalived_scripts, {
        :haproxy => {
          :script => 'killall -0 haproxy',
          :interval => 1,
          :weight => 2
        }
      }

      # :keepalived_instances should contain a hash with at least one key => value pair. The key should be a string
      # with the virtual IP address. The value is again a hash with some settings, containing as key => value pairs:
      # :virtual_router_id => '51' or any unique integer among all VRRP instances on the same subnet
      # :interface => 'eth0'
      # :priority => '101', usually should be one higher for MASTER than for BACKUP
      # :state => 'MASTER' or 'BACKUP', automatically adds :wanted_state to :scripts below
      # :scripts => symbol or hash of scripts to execute for this instance, when left undefined all scripts defined above
      # are added
      set :keepalived_instances, {
        "192.168.0.99" => {
          :virtual_router_id => '51',
          :interface => 'eth0',
          :priority => '101',
          :state => 'MASTER',
          :scripts => :haproxy
        }
      }
      
      set :keepalived_syslog_facility, nil # set to a number from 0 to 7 to use local0 - local7
  
      SRC_PACKAGES[:keepalived] = {
        :md5sum => "6c3065c94bb9e2187c4b5a80f6d8be31  keepalived-1.1.20.tar.gz",
        :url => "http://www.keepalived.org/software/keepalived-1.1.20.tar.gz"
      }
      
      desc "Install keepalived on server"
      task :install, :roles => :failover do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:keepalived], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:keepalived], src_dir)
        config
        activate
        update_sysctl
      end
  
      task :install_deps, :roles => :failover do
        apt.install( {:base => %w(build-essential libssl-dev libpopt-dev)}, :stable )
      end
  
      SYSTEM_CONFIG_FILES[:keepalived] = [
        {:template => 'keepalived.conf.erb',
         :path => '/etc/keepalived/keepalived.conf',
         :mode => 0644,
         :owner => 'root:root'},
        {:template => 'keepalived-init.erb',
         :path => '/etc/init.d/keepalived',
         :mode => 0755,
         :owner => 'root:root'}
      ]
    
      desc "Generate config files for keepalived"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:keepalived].each do |file|
          deprec2.render_template(:keepalived, file)
        end
      end
  
      desc "Push keepalived config files to server"
      task :config, :roles => :failover do
        deprec2.push_configs(:keepalived, SYSTEM_CONFIG_FILES[:keepalived])
        reactivate
      end
  
      task :update_sysctl, :roles => :failover do
        deprec2.append_to_file_if_missing('/etc/sysctl.conf', 'net.ipv4.ip_nonlocal_bind=1')
        sudo 'sysctl -p'
      end
  
      task :start, :roles => :failover do
        sudo "/etc/init.d/keepalived start"
      end

      task :stop, :roles => :failover do
        sudo "/etc/init.d/keepalived stop"
      end
  
      task :restart do
        stop
        start
      end

      task :activate, :roles => :failover do
        sudo "update-rc.d keepalived start 50 S . stop 9 0 6 ."
      end
  
      task :deactivate, :roles => :failover do
        sudo "update-rc.d -f keepalived remove"
      end
  
      task :reactivate do
        deactivate
        activate
      end
  
    end
  end
end