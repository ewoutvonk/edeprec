# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :ssh do
      
      # define SSH keys for each user
      # :ssh_user_keys should be a hash, with:
      # * the keys being any identifier for the user
      # * the values being either:
      # ** one SSH key in the form of a string
      # ** multiple SSH keys in the form of an array of strings
      # Define this variable in the main deploy.rb when using multistage capistrano
      set :ssh_user_keys, { }
      # :ssh_users should contain an array of user identifiers as defined in :ssh_user_keys,
      # use this variable to define which users have access to the all the servers defined.
      # Specify this variable in a stage deploy file when using multistage capistrano
      # (so you can have different users have access to different servers)
      set :ssh_users, [ ]
      # :ssh_known_hosts variable should contain the hostnames or IP addresses (as an array of strings)
      # of all hosts that should be put in the deploy_user's known_hosts file. This known_hosts file will
      # be put on all defined servers.
      set :ssh_known_hosts, [ ]

      SYSTEM_CONFIG_FILES[:ssh] = [
        
        {:template => "sshd_config.erb",
         :path => '/etc/ssh/sshd_config',
         :mode => 0644,
         :owner => 'root:root'},
         
        {:template => "ssh_config.erb",
         :path => '/etc/ssh/ssh_config',
         :mode => 0644,
         :owner => 'root:root'}
      ]
      
      task :config_gen do        
        SYSTEM_CONFIG_FILES[:ssh].each do |file|
          deprec2.render_template(:ssh, file)
        end
        auth_keys_dir = 'config/ssh/authorized_keys'
        if ! File.directory?(auth_keys_dir)
          puts "Creating #{auth_keys_dir}"
          Dir.mkdir(auth_keys_dir)
        end
      end
      
      desc "Push ssh config files to server"
      task :config do
        deprec2.push_configs(:ssh, SYSTEM_CONFIG_FILES[:ssh])
        restart
      end

      # set access for SSH:
      # * add keys of users to authorized_keys file of deploy_user
      # * add host keys to known hosts file of deploy_user
      desc "create authorized_keys and known_hosts files on servers"
      task :set_access do
        if ssh_users.size > 0
          run "rm -f ~/.ssh/authorized_keys.new"
          run "touch ~/.ssh/authorized_keys.new"
          run "chmod 600 ~/.ssh/authorized_keys.new"
          ssh_users.each do |ssh_user|
            keys = [ssh_user_keys[ssh_user]].flatten
            keys.each do |ssh_key|
              deprec2.append_to_file_if_missing('~/.ssh/authorized_keys.new', ssh_key)
            end
          end
          run "cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak"
          run "mv ~/.ssh/authorized_keys.new ~/.ssh/authorized_keys"
        end

        require 'socket'
        if ssh_known_hosts.size > 0
          hosts_and_ips = (ssh_known_hosts + ssh_known_hosts.collect { |h| Socket.getaddrinfo(h, 0, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP, Socket::INADDR_ANY).first[3] })
          put (hosts_and_ips + [""]).join("\n"), tmp_file = "/tmp/ssh_keyscan_#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", :mode => 0644
          run "ssh-keyscan -f #{tmp_file} -t rsa > ~/.ssh/known_hosts"
          run "rm -f #{tmp_file}"
        end
      end
      
      desc "Start ssh"
      task :start do
        send(run_method, "/etc/init.d/ssh reload")
      end
    
      desc "Stop ssh"
      task :stop do
        send(run_method, "/etc/init.d/ssh reload")
      end
    
      desc "Restart ssh"
      task :restart do
        send(run_method, "/etc/init.d/ssh restart")
      end
    
      desc "Reload ssh"
      task :reload do
        send(run_method, "/etc/init.d/ssh reload")
      end
      
      desc "Sets up authorized_keys file on remote server"
      task :setup_keys do
        
        default(:target_user) { 
          Capistrano::CLI.ui.ask "Setup keys for which user?" do |q|
            q.default = user
          end
        }
        
        # If we have an authorized keys file for this user
        # then copy that out
        if File.exists?("config/ssh/authorized_keys/#{target_user}") 
          deprec2.mkdir "/home/#{target_user}/.ssh", :mode => 0700, :owner => "#{target_user}.users", :via => :sudo
          std.su_put File.read("config/ssh/authorized_keys/#{target_user}"), "/home/#{target_user}/.ssh/authorized_keys", '/tmp/', :mode => 0600
          sudo "chown #{target_user}.users /home/#{target_user}/.ssh/authorized_keys"
        
        elsif target_user == user
          
          # If the user has specified a key Capistrano should use
          if ssh_options[:keys]
            deprec2.mkdir '.ssh', :mode => 0700
            put(ssh_options[:keys].collect{|key| File.read("#{key}.pub")}.join("\n"), '.ssh/authorized_keys', :mode => 0600 )
          
          # Try to find the current users public key
          elsif keys = %w[id_rsa id_dsa identity].collect { |f| "#{ENV['HOME']}/.ssh/#{f}.pub" if File.exists?("#{ENV['HOME']}/.ssh/#{f}.pub") }.compact
            deprec2.mkdir '.ssh', :mode => 0700
            put(keys.collect{|key| File.read(key)}.join("\n"), '.ssh/authorized_keys', :mode => 0600 )
            
          else
            puts <<-ERROR

            You need to define the name of your SSH key(s)
            e.g. ssh_options[:keys] = %w(/Users/your_username/.ssh/id_rsa)

            You can put this in your .caprc file in your home directory.

            ERROR
            exit
          end
        else
          puts <<-ERROR
          
          Could not find ssh public key(s) for user #{user}
          
          Please create file containing ssh public keys in:
          
            config/ssh/authorized_keys/#{target_user}
            
          ERROR
        end
        
      end
      
    end
  end
end