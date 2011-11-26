# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :thinking_sphinx do
      
      SRC_PACKAGES[:thinking_sphinx] = {
        :filename => 'sphinx-0.9.9.tar.gz',   
        :dir => 'sphinx-0.9.9',  
        :url => "http://www.sphinxsearch.com/downloads/sphinx-0.9.9.tar.gz",
        :unpack => "tar zxf sphinx-0.9.9.tar.gz;",
        :configure => %w(
          ./configure
          ;
          ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make;',
        :install => 'make install;'
      }
      
      desc "install Sphinx Search Engine"
      task :install, :roles => :sphinx do
        deprec2.download_src(SRC_PACKAGES[:thinking_sphinx], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:thinking_sphinx], src_dir)
      end
    
      SYSTEM_CONFIG_FILES[:sphinx] = []
      
      PROJECT_CONFIG_FILES[:sphinx] = [

        {:template => 'monit.conf.erb',
         :path => 'monit.conf',
         :mode => 0644,
         :owner => 'root:root'}
      
      ]

      desc <<-DESC
      Generate sphinx config from template. Note that this does not
      push the config to the server, it merely generates required
      configuration files. These should be kept under source control.            
      The can be pushed to the server with the :config task.
      DESC
      task :config_gen do
        PROJECT_CONFIG_FILES[:sphinx].each do |file|
          deprec2.render_template(:sphinx, file)
        end
      end

      desc "Push sphinx config files to server"
      task :config, :roles => :sphinx do
        config_project
      end
      
      desc "Push sphinx config files to server"
      task :config_project, :roles => :sphinx do
        deprec2.push_configs(:sphinx, PROJECT_CONFIG_FILES[:sphinx])
        symlink_monit_config
      end
      
      task :symlink_monit_config, :roles => :sphinx do
        sudo "ln -sf #{deploy_to}/sphinx/monit.conf #{monit_confd_dir}/sphinx_#{application}.conf"
      end

      desc "Init the sphinx searchd daemon (using Thinking Sphinx)"
      task :init, :roles => :sphinx do
        unless ENV['NO_SPHINX']
          run "rm -f #{shared_path}/config/#{rails_env}.sphinx.conf"
          run "rm -f #{current_path}/config/#{rails_env}.sphinx.conf"
          run "ln -nsf #{shared_path}/config/#{rails_env}.sphinx.conf #{current_path}/config/"
          run "sh -c 'cd #{current_path} ; rake ts:config RAILS_ENV=#{rails_env}'"
          run "mkdir -p #{shared_path}/db/sphinx"
          run "rm -rf #{current_path}/db/sphinx"
          run "ln -nsf #{shared_path}/db/sphinx #{current_path}/db/"
          run "sh -c 'cd #{current_path} ; rake ts:index RAILS_ENV=#{rails_env}'"
          run "sh -c 'cd #{current_path} ; rake ts:start RAILS_ENV=#{rails_env}'"
        end
      end

      desc "Start the sphinx searchd daemon (using Thinking Sphinx)"
      task :start, :roles => :sphinx do
        run "cd #{current_path} ; rake ts:restart RAILS_ENV=#{rails_env}"
      end

      desc "Restart the sphinx searchd daemon (using Thinking Sphinx)"
      task :restart, :roles => :sphinx do
        run "cd #{current_path} ; rake ts:restart RAILS_ENV=#{rails_env}"
      end

      desc "Stop the sphinx searchd daemon (using Thinking Sphinx)"
      task :stop, :roles => :sphinx do
        run "cd #{current_path} ; rake ts:stop RAILS_ENV=#{rails_env}"
      end

      desc "Index the sphinx searchd daemon (using Thinking Sphinx)"
      task :reindex, :roles => :sphinx do
        run "cd #{current_path} ; rake ts:index RAILS_ENV=#{rails_env}"
      end

      desc "Configure the sphinx searchd daemon (using Thinking Sphinx)"
      task :reconfig, :roles => [:app, :sphinx] do
        run "cd #{current_path} ; bin/rake ts:config RAILS_ENV=#{rails_env} SPHINX_RAILS_ROOT=/apps/#{application}/current"
      end

    end 
  end
end