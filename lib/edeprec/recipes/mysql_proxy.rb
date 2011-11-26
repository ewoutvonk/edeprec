# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :mysql_proxy do
  
      set :mysql_proxy_backend_servers, [ '192.168.0.1' ]
      set :mysql_proxy_read_only_backend_servers, [ '192.168.0.2', '192.168.0.3' ]
  
      desc "Install mysql_proxy on server"
      task :install, :roles => :proxy do
        install_deps
        config
        reactivate
      end
  
      task :install_deps, :roles => :proxy do
        apt.install( {:base => %w(mysql-proxy)}, :stable )
      end
  
      SYSTEM_CONFIG_FILES[:mysql_proxy] = [
        {:template => 'mysql-proxy-default.erb',
         :path => '/etc/default/mysql-proxy',
         :mode => 0644,
         :owner => 'root:root'}
      ]
  
      desc "Generate config files for mysql_proxy"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:mysql_proxy].each do |file|
          deprec2.render_template(:mysql_proxy, file)
        end
      end
  
      desc "Push mysql_proxy config files to server"
      task :config, :roles => :proxy do
        deprec2.push_configs(:mysql_proxy, SYSTEM_CONFIG_FILES[:mysql_proxy])
      end

      task :start, :roles => :proxy do
        sudo "/etc/init.d/mysql-proxy start"
      end

      task :stop, :roles => :proxy do
        sudo "/etc/init.d/mysql-proxy stop"
      end
  
      task :restart do
        stop
        start
      end

      task :activate, :roles => :proxy do
        sudo "update-rc.d mysql-proxy defaults"
      end
  
      task :deactivate, :roles => :proxy do
        sudo "update-rc.d -f mysql-proxy remove"
      end
  
      task :reactivate do
        deactivate
        activate
      end
  
    end
  end
end