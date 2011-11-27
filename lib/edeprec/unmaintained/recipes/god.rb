# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :god do
      
      desc "install god"
      task :install do
        gem2.install 'god'
      end
    
      SYSTEM_CONFIG_FILES[:god] = [
        
        {:template => "god-init.erb",
         :path => '/etc/init.d/god',
         :mode => 0755,
         :owner => 'root:root'},

        {:template => "god-conf.erb",
         :path => '/etc/god/god.conf',
         :mode => 0755,
         :owner => 'root:root'}
        
      ]
      
      desc <<-DESC
      Generate god config from template. Note that this does not
      push the config to the server, it merely generates required
      configuration files. These should be kept under source control.            
      The can be pushed to the server with the :config task.
      DESC
      task :config_gen do
        SYSTEM_CONFIG_FILES[:god].each do |file|
          deprec2.render_template(:god, file)
        end
      end

      desc "Push god config files to server"
      task :config, :roles => :god do
        config_system
        config_project
      end

      task :config_system, :roles => :god do
        sudo "install -d /etc/god/conf.d"
        deprec2.push_configs(:god, SYSTEM_CONFIG_FILES[:god])
      end
      
      # Push any files named *.god.#{rails_env} in directory config/god/ to servers with :god role,
      # remove the .#{rails_env} extension and put them in #{deploy_to}/god/. Next, link them to /etc/god/conf.d/
      task :config_project, :roles => :god do
        Dir.new(File.join("config", "god")).entries.select { |e| e =~ /\.god\.#{rails_env}$/ }.each do |entry|
          base_entry = File.basename(entry, ".#{rails_env}")
          file = File.join("config", "god", entry)
          full_remote_path = File.join(deploy_to, 'god', base_entry)
          run "mkdir -p #{File.join(deploy_to, 'god')}"
          std.su_put File.read(file), full_remote_path, '/tmp/', :mode=>0644
          sudo "chown root:root #{full_remote_path}"
          sudo "ln -nsf #{full_remote_path} /etc/god/conf.d/#{application}-#{base_entry}"
        end if File.directory?(File.join("config", "god"))
      end

      desc "Start God"
      task :start, :roles => :god do
        send(run_method, "/etc/init.d/god start")
      end

      desc "Stop God"
      task :stop, :roles => :god do
        send(run_method, "/etc/init.d/god stop")
      end

      desc "Restart God"
      task :restart, :roles => :god do
        send(run_method, "/etc/init.d/god restart")
      end

      desc "Set God to start on boot"
      task :activate, :roles => :god do
        send(run_method, "update-rc.d god defaults")
      end
      
      desc "Set God to not start on boot"
      task :deactivate, :roles => :god do
        send(run_method, "update-rc.d -f god remove")
      end
      
    end 
  end
end