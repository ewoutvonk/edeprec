# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :mongodb do
      
      SRC_PACKAGES[:mongodb] = {
        :filename => 'mongodb-src-r1.4.0.tar.gz',   
        :dir => 'mongodb-src-r1.4.0',  
        :url => "http://downloads.mongodb.org/src/mongodb-src-r1.4.0.tar.gz",
        :unpack => "tar zxf mongodb-src-r1.4.0.tar.gz;",
        :configure => '',
        :make => 'scons all;',
        :install => 'scons --prefix=/usr/local/mongo install;'
      }
      
      # Installs MongoDB on Ubuntu 8.04. 
      # Still gives:
      #  warning built with boost version 1.34 or older - limited concurrency
      desc "install MongoDB"
      task :install, :roles => :mongodb do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:mongodb], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:mongodb], src_dir)
        sudo 'mkdir -p /var/lib/mongodb' # Data dir, also pid/lock file is in there (see init.d script)
      end

      # Install dependencies for MongoDB
      task :install_deps, :roles => :mongodb do
        # See: http://www.mongodb.org/display/DOCS/Building+for+Linux
        apt.install( {:base => %w(tcsh git-core scons g++)}, :stable )
        apt.install( {:base => %w(libpcre++-dev libboost-dev libreadline-dev xulrunner-1.9-dev)}, :stable )
        apt.install( {:base => %w(libboost-program-options-dev libboost-thread-dev libboost-filesystem-dev libboost-date-time-dev)}, :stable )
      end

      SYSTEM_CONFIG_FILES[:mongodb] = [

        {:template => "mongodb-init.d",
         :path => '/etc/init.d/mongodb',
         :mode => 0755,
         :owner => 'root:root'}
        
        ]
      
      PROJECT_CONFIG_FILES[:mongodb] = []

      desc "Generate configuration files for mongodb from template(s)"
      task :config_gen do
        config_gen_system
      end

      task :config_gen_system do
        SYSTEM_CONFIG_FILES[:mongodb].each do |file|
          deprec2.render_template(:mongodb, file)
        end
      end

      desc 'Deploy configuration files for mongodb' 
      task :config, :roles => :mongodb do
        config_system
      end

      task :config_system, :roles => :mongodb do
        deprec2.append_to_file_if_missing('/etc/profile', 'export PATH=$PATH:/usr/local/mongo/bin')
        deprec2.push_configs(:mongodb, SYSTEM_CONFIG_FILES[:mongodb])
      end

      desc 'Start mongodb via init.d script' 
      task :start, :roles => :mongodb do
        run "#{sudo} /etc/init.d/mongodb start"
      end
      
      desc 'Stop mongodb via init.d script' 
      task :stop, :roles => :mongodb do
        run "#{sudo} /etc/init.d/mongodb stop"
      end
      
      desc 'Restart mongodb via init.d script' 
      task :restart, :roles => :mongodb do
        run "#{sudo} /etc/init.d/mongodb restart"
      end

      desc 'Activate mongodb init.d script to start at boot' 
      task :activate, :roles => :mongodb do
        run "#{sudo} update-rc.d mongodb defaults"
      end  
      
      desc 'Deactivate mongodb init.d script to NOT start at boot' 
      task :deactivate, :roles => :mongodb do
        run "#{sudo} update-rc.d -f mongodb remove"
      end

    end 
  end
end