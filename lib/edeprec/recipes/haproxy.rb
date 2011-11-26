# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :haproxy do
      
      SRC_PACKAGES[:haproxy] = {
        :md5sum => "104f4985b37bd9bac7a33e20fb6aaadf  haproxy-1.4.8.tar.gz",
        :url => "http://haproxy.1wt.eu/download/1.4/src/haproxy-1.4.8.tar.gz",
        :configure => '',
        :make => "TARGET=linux26"

      }
      
      set :haproxy_user, 'root'
      set :haproxy_group, 'root'
      
      # :haproxy_global_options should be a hash of options, in key => value pairs. Values can also be arrays of strings.
      set :haproxy_global_options, {
        "log" => "/var/log/haproxy.log daemon info",
        "maxconn" => 4096,
        "pidfile" => "/var/run/haproxy.pid",
        "daemon" => true
      }

      # :haproxy_default_options should be a hash of options, in key => value pairs. 
      #  :stats_auth => 'user:password' presence of this setting automatically enables stats
      #  :options => hash of options, in key => value pairs. Values can also be arrays of strings. 
      set :haproxy_default_options, {
        :stats_auth => 'user:password',
        :options => {
          "option" => [
            "forwardfor",
            "httpclose",
            "redispatch"
          ],
          "balance" => "roundrobin",
          "mode" => "http",
          "retries" => 3,
          "maxconn" => 2000,
          "contimeout" => 5000,
          "clitimeout" => 50000,
          "srvtimeout" => 50000
        }
      }

      task :create_haproxy_user, :roles => :haproxy do
        deprec2.groupadd(haproxy_group) unless haproxy_group == 'root'
        deprec2.useradd(haproxy_user, :group => haproxy_group) unless haproxy_user == 'root'
      end
      
      # :haproxy_instances should contain a hash with at least one key => value pair. The key should be a string
      #  with the virtual IP address. The value is again a hash with some settings, containing as key => value pairs:
      #  :name => 'name_of_webfarm'
      #  :stats_auth => 'user:password' presence of this setting automatically enables stats
      #  :servers => hash of servers, in key => value pairs:
      #   'web1' => '127.0.0.1:80 weight 6  maxconn 12 check'
      #  :options => hash of options, in key => value pairs. Values can also be arrays of strings.      
      set :haproxy_instances, {
        "*:81" => {
          :name => "example_lb",
          :stats_auth => 'user:password',
          :servers => {
            'web1' => '127.0.0.1:80 weight 6  maxconn 12 check',
            'web2' => '127.0.0.1:80 weight 10 maxconn 12 check'
          },
          :options => {
            "option" => [
              "httpchk HEAD /check.txt HTTP/1.0"
            ]
          }
        }
      }
      
      desc "Install haproxy"
      task :install, :roles => :haproxy do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:haproxy], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:haproxy], src_dir)
        config
        activate
        create_check_file
        create_haproxy_user
      end

      # default config expects this file in web root
      # check file should be created on webservers
      task :create_check_file, :roles => :web do
        sudo "test -d /var/www && #{sudo} touch /var/www/check.txt"
      end
      
      task :install_deps, :roles => :haproxy do
        apt.install( {:base => %w(build-essential)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:haproxy] = [
        
        {:template => "haproxy.cfg.erb",
         :path => '/etc/haproxy.cfg',
         :mode => 0644,
         :owner => 'root:root'},
        
        {:template => "haproxy-init.d",
         :path => '/etc/init.d/haproxy',
         :mode => 0755,
         :owner => 'root:root'}
         
      ]

      PROJECT_CONFIG_FILES[:haproxy] = [
        
        # {:template => "example.conf.erb",
        #  :path => 'conf/example.conf',
        #  :mode => 0755,
        #  :owner => 'root:root'}
      ]
      
      desc "Generate configuration files for haproxy from template(s)"
      task :config_gen do
        config_gen_system
        config_gen_project
      end

      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:haproxy].each do |file|
          deprec2.render_template(:haproxy, file)
        end
      end

      task :config_gen_project do
        PROJECT_CONFIG_FILES[:haproxy].each do |file|
          deprec2.render_template(:haproxy, file)
        end
      end
      
      desc 'Deploy configuration filess for haproxy' 
      task :config, :roles => :haproxy do
        config_system
        # config_project
      end

      task :config_system, :roles => :haproxy do
        deprec2.push_configs(:haproxy, SYSTEM_CONFIG_FILES[:haproxy])
      end

      task :config_project, :roles => :haproxy do
        deprec2.push_configs(:haproxy, PROJECT_CONFIG_FILES[:haproxy])
      end
      
      
      task :start, :roles => :haproxy do
        run "#{sudo} /etc/init.d/haproxy start"
      end
      
      task :stop, :roles => :haproxy do
        run "#{sudo} /etc/init.d/haproxy stop"
      end
      
      task :restart, :roles => :haproxy do
        run "#{sudo} /etc/init.d/haproxy restart"
      end
      
      task :reload, :roles => :haproxy do
        run "#{sudo} /etc/init.d/haproxy reload"
      end
      
      task :activate, :roles => :haproxy do
        run "#{sudo} update-rc.d haproxy defaults"
      end  
      
      task :deactivate, :roles => :haproxy do
        run "#{sudo} update-rc.d -f haproxy remove"
      end
      
    end
  end
end
