# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :ubuntu do

      set :ubuntu_default_term, :linux
      set :ubuntu_packages_to_install, %w(cron nmap nano bind9-host man-db screen dnsutils iptraf apache2-utils makepasswd psmisc)
      set :ubuntu_apt_preferences, nil # set to a string to upload /etc/apt/preferences
      set :ubuntu_users_remove_admin_group, [] # set to one or more users who should be part of sudo group, but not admin group (for /etc/sudoers to work by default)

      SYSTEM_CONFIG_FILES[:ubuntu] = [
        
        {:template => "getlibs.erb",
         :path => '/usr/local/bin/getlibs',
         :mode => 0755,
         :owner => 'root:root'}
         
      ]
      
      desc "apt-get update. Resynchronize the package index files from their sources."
      task :update do
        top.deprec.ubuntu.upload_apt_preferences
        apt.update
      end
      
      desc "Install useful ubuntu packages"
      task :install do
        apt.install( {:base => ubuntu_packages_to_install}, :stable )
      end
      
      desc "Install 32 bit library support"
      task :install_32bit_libs_support do
        # support 32-bit builds on 64-bit
        apt.install( {:base => %w(gcc-multilib libc6-i386 libc6-dev-i386)}, :stable )
        SYSTEM_CONFIG_FILES[:ubuntu].each do |file|
          deprec2.render_template(:ubuntu, file.merge(:remote => true))
        end
      end
      
      desc "apt-get upgrade. Install the newest versions of all packages currently
                 installed on the system from the sources enumerated in /etc/apt/sources.list.."
      task :upgrade do
        apt.upgrade
      end

      desc "reboot the server"
      task :restart do
        sudo "reboot"
      end
      
      desc "shut down the server"
      task :shutdown do
        sudo "shutdown -h now"
      end
      
      desc "Remove locks from aborted apt-get command."
      task :remove_locks do
        sudo "rm /var/lib/apt/lists/lock"
        # XXX There's one more - add it!
      end
      
      task :remove_admin_group_from_users do
        ([ubuntu_users_remove_admin_group] || []).flatten.each do |user|
          sudo "perl -p -i -e 's/^(admin:x:[0-9]+:)([^,]+,)*#{user}(,[^,]+)*/$1/' /etc/group"
        end
      end
      
      task :upload_apt_preferences do
        if ubuntu_apt_preferences
          put ubuntu_apt_preferences, "/tmp/preferences", :mode => 0644
          sudo "chown root:root /tmp/preferences"
          sudo "mv /tmp/preferences /etc/apt/"
        end
      end

      namespace :utils do
        
        namespace :bash do
          
          task :config do
            deprec2.append_to_file_if_missing('/etc/profile', "export TERM=#{ubuntu_default_term}")
            deprec2.append_to_file_if_missing('/etc/profile', "export RAILS_ENV=#{rails_env}")
          end
          
        end
        
        namespace :cron do
          
          desc "List installed global crons"
          task :list do
            sudo "ls /etc/cron.d"
          end

          desc "Remove all installed global crons"
          task :remove_all do
            sudo "rm -f /etc/cron.d/*"
          end
          
        end
        
        namespace :sys do
          
          desc "View memstats"
          task :free do
            run "free"
          end
          
          desc "Identify servers affected"
          task :ident do
            run "hostname"
          end
          
          desc "Show server IP addresses"
          task :ip do
            run "{ sudo ip addr show dev eth0 | grep inet | grep -v inet6 ; sudo ip addr show dev peth0 | grep inet | grep -v inet6 ; }"
          end
          
        end
        
        
      end
      
    end
  end
end
