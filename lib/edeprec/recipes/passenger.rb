# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :passenger do
          
      set(:passenger_install_dir) {
        if ruby_choice == :ree
          "#{ree_install_dir}/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}"
        elsif ruby_choice == :rvm && (rvm_default_ruby || 'custom').to_sym != :system
          ruby_dir = capture("rvm info homes").split("\n").grep(/^\s*gem:/).first.split(/\s/).select { |x| !x.empty? && x != "gem:" }.first.gsub(/\"/, '')
          "#{ruby_dir}/gems/passenger-#{passenger_version}"
        else
          "/usr/local/lib/ruby/gems/1.8/gems/passenger-#{passenger_version}"
        end
      }
      
      set(:passenger_ruby) {
        if ruby_choice == :ree
          "#{ree_install_dir}/bin/ruby"
        elsif ruby_choice == :rvm
          rvm_default_ruby.to_sym == :system ? "/usr/local/bin/passenger_ruby" : File.join(capture("pwd").chomp, '.rvm', 'bin', 'passenger_ruby')
        else
          "/usr/local/bin/ruby"
        end
      }

      set :passenger_log_level, 0
      set :passenger_user_switching, 'on'
      set :passenger_default_user, 'nobody'
      set :passenger_max_pool_size, 6
      set :passenger_max_instances_per_app, 0
      set :passenger_pool_idle_time, 300
      set :passenger_rails_autodetect, 'on'
      set :passenger_rails_spawn_method, 'smart' # smart | conservative
      set :passenger_version, '2.2.11'
      set :passenger_disable_modules, []
      set :passenger_enable_modules, []
      set :passenger_disable_sites, []
      set :passenger_extra_vhosts, {} # key should be name of file in /etc/apache2/sites-available, value should be contents

      desc "Install passenger"
      task :install, :roles => :passenger do
        install_deps
        gem2.install 'passenger', passenger_version
        if ruby_choice == :rvm
          run "rvmsudo passenger-install-apache2-module -a"
        else
          sudo "passenger-install-apache2-module -a"
        end
        initial_config_push
        activate_system
      end
      
      # Install dependencies for Passenger
      task :install_deps, :roles => :passenger do
        apt.install( {:base => %w(apache2-mpm-prefork apache2-prefork-dev rsync)}, :stable )
        gem2.install 'fastthread'
        gem2.install 'rack'
        gem2.install 'rake'
      end
      
      task :initial_config_push, :roles => :passenger do
        SYSTEM_CONFIG_FILES[:passenger].each do |file|
          deprec2.render_template(:passenger, file.merge(:remote => true))
        end
      end

      SYSTEM_CONFIG_FILES[:passenger] = [

        {:template => 'passenger.load.erb',
          :path => '/etc/apache2/mods-available/passenger.load',
          :mode => 0755,
          :owner => 'root:root'},
          
        {:template => 'passenger.conf.erb',
          :path => '/etc/apache2/mods-available/passenger.conf',
          :mode => 0755,
          :owner => 'root:root'}

      ]

      desc "Generate Passenger apache configs"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:passenger].each do |file|
          deprec2.render_template(:passenger, file)
        end
      end

      desc "Push Passenger config files to server"
      task :config, :roles => :passenger do
        deprec2.push_configs(:passenger, SYSTEM_CONFIG_FILES[:passenger])
        symlink_extra_apache_vhosts
        disable_modules
        enable_modules
        disable_sites
      end

      task :symlink_extra_apache_vhosts, :roles => :passenger do
        passenger_extra_vhosts.each do |name, vhost|
          put vhost, tmp_file = "/tmp/apache_default_vhost_#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", :mode => 0644
          sudo "chown root:root #{tmp_file}"
          sudo "mv #{tmp_file} /etc/apache2/sites-available/#{name}"
          sudo "a2ensite #{name}"
        end
      end
      
      task :disable_modules, :roles => :passenger do
        passenger_disable_modules.each do |apache_module|
          sudo "a2dismod #{apache_module}"
        end
      end

      task :enable_modules, :roles => :passenger do
        passenger_enable_modules.each do |apache_module|
          sudo "a2enmod #{apache_module}"
        end
      end

      task :disable_sites, :roles => :passenger do
        passenger_disable_sites.each do |apache_vhost|
          sudo "a2dissite #{apache_vhost}"
        end
      end
      
      task :activate, :roles => :passenger do
        sudo "a2enmod passenger"
      end
      
      task :deactivate, :roles => :passenger do
        sudo "a2dismod passenger"
      end
      
    end
    
  end
end
