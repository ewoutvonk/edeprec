# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :nagios do
      
      set :nagios_user, 'nagios'
      set :nagios_group, 'nagios'
      set(:nagios_host) { Capistrano::CLI.ui.ask "Enter hostname of nagios server" }
      set(:nagios_ip) { Capistrano::CLI.ui.ask "Enter ip address of nagios server" }
      set(:nagios_admin_pass) { Capistrano::CLI.ui.ask "Enter password for nagiosadmin user" }
      set :nagios_cmd_group, 'nagcmd' # Submit external commands through the web interface
      set :nagios_htpasswd_file, '/usr/local/nagios/etc/htpasswd.users'
      # default :application, 'nagios' 
      set :nagios_ssh_key, nil
      # all SSH hostnames or IPs that nagios should check
      set :nagios_known_hosts, [ ]
      # allow nagios user on check_hosts to do certain commands through sudo
      set :nagios_sudo_commands, [ ] # i.e.: %w(/usr/bin/killall /bin/kill /sbin/iptables /bin/cat)
      
      SRC_PACKAGES[:nagios] = {
        :url => "http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-3.2.0.tar.gz",
        :md5sum => "3566167cc60ddeaad34e7d2e26ed4a58  nagios-3.2.0.tar.gz", 
        :configure => "./configure --with-command-group=nagcmd;",
        :make => 'make all;',
        :install => 'make install install-init install-commandmode install-webconf;'
      }
      
      desc "Install and configure Nagios server"
      task :setup_server, :roles => :nagios do
        install
        top.deprec.nagios_plugins.install
        top.deprec.nrpe.install
        config_gen
        config
      end
      
      desc "Setup client"
      task :setup_client do
        top.deprec.nagios_plugins.install
        top.deprec.nrpe.install
        top.deprec.nrpe.config
      end
      
      desc "Install nagios"
      task :install, :roles => :nagios do
        install_deps
        create_nagios_user
        deprec2.download_src(SRC_PACKAGES[:nagios], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nagios], src_dir)
      end
      
      # Install dependencies for nagios
      task :install_deps, :roles => :nagios do
        apt.install( {:base => %w(apache2 mailx postfix libapache2-mod-php5 libgd2-xpm-dev)}, :stable )
      end
      
      task :create_nagios_user, :roles => :nagios do
        deprec2.groupadd(nagios_group)
        deprec2.useradd(nagios_user, :group => nagios_group)
        # deprec2.add_user_to_group(nagios_user, apache_user)
        deprec2.groupadd(nagios_cmd_group)
        deprec2.add_user_to_group(nagios_user, nagios_cmd_group)
        deprec2.add_user_to_group(apache_user, nagios_cmd_group)        
      end
      
      desc "Grant a user access to the web interface"
      task :htpass, :roles => :nagios do
        target_user = Capistrano::CLI.ui.ask "Userid" do |q|
          q.default = 'nagiosadmin'
        end
        system "htpasswd config/nagios/usr/local/nagios/etc/htpasswd.users #{target_user}"
      end
      
      # desc "Set password for web based access"
      # task :htpass do
      #   target_user = Capistrano::CLI.ui.ask "Userid" do |q| 
      #     q.default = 'nagiosadmin'
      #   end
      #   newpass = Capistrano::CLI.ui.ask "new password" do |q| 
      #     q.echo = false 
      #   end
      #   sudo "htpasswd -b #{htpasswd_file} #{target_user} #{newpass}"
      # end
      
      SYSTEM_CONFIG_FILES[:nagios] = [
        
        {:template => 'cgi.cfg.erb',
        :path => '/usr/local/nagios/etc/cgi.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'htpasswd.users',
        :path => '/usr/local/nagios/etc/htpasswd.users',
        :mode => 0660,
        :owner => 'nagios:www-data'},
        
        {:template => 'nagios.cfg.erb',
        :path => '/usr/local/nagios/etc/nagios.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'resource.cfg.erb',
        :path => '/usr/local/nagios/etc/resource.cfg',
        :mode => 0660,
        :owner => 'nagios:nagios'},
        
        {:template => 'objects/commands.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/commands.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'objects/contacts.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/contacts.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'objects/hosts.cfg.erb',
        :path => '/usr/local/nagios/etc/objects/hosts.cfg',
        :mode => 0664,
        :owner => 'nagios:nagios'},
        
        {:template => 'objects/localhost.cfg.erb',
         :path => '/usr/local/nagios/etc/objects/localhost.cfg',
         :mode => 0664,
         :owner => 'nagios:nagios'},
         
        {:template => 'objects/services.cfg.erb',
         :path => '/usr/local/nagios/etc/objects/services.cfg',
         :mode => 0664,
         :owner => 'nagios:nagios'},
        
        {:template => 'objects/timeperiods.cfg.erb',
         :path => '/usr/local/nagios/etc/objects/timeperiods.cfg',
         :mode => 0664,
         :owner => 'nagios:nagios'}
      
      ]

      desc "Generate configuration file(s) for nagios from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:nagios].each do |file|
          deprec2.render_template(:nagios, file)
        end
      end
      
      desc "Push nagios config files to server"
      task :config, :roles => :nagios do
        default :application, 'nagios'
        deprec2.push_configs(:nagios, SYSTEM_CONFIG_FILES[:nagios])
        config_check
        restart
        require 'socket'
        if nagios_known_hosts.size > 0
          hosts_and_ips = (nagios_known_hosts + nagios_known_hosts.collect { |h| Socket.getaddrinfo(h, 0, Socket::AF_INET, Socket::SOCK_STREAM, Socket::IPPROTO_TCP, Socket::INADDR_ANY).first[3] })
          put (hosts_and_ips + [""]).join("\n"), tmp_file = "/tmp/ssh_keyscan_#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", :mode => 0644
          tmp_out_file = "/tmp/known_hosts_#{Time.now.strftime("%Y%m%d%H%M%S")}.txt"
          run "ssh-keyscan -f #{tmp_file} -t rsa > #{tmp_out_file}"
          run "rm -f #{tmp_file}"
          sudo "cp #{tmp_out_file} ~nagios/.ssh/known_hosts"
          run "rm -f #{tmp_out_file}"
          sudo "chown #{nagios_user}:#{nagios_group} ~nagios/.ssh/known_hosts"
        end
      end
      
      desc "Run Nagios config check"
      task :config_check, :roles => :nagios do
        send(run_method, "/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg")
      end
      
      # desc "Set Nagios to start on boot"
      # task :activate, :roles => :nagios do
      #   send(run_method, "update-rc.d nagios defaults")
      #   sudo "a2ensite nagios"
      #   top.deprec.apache.reload
      # end
      # 
      # desc "Set Nagios to not start on boot"
      # task :deactivate, :roles => :nagios do
      #   send(run_method, "update-rc.d -f nagios remove")
      #   sudo "a2dissite nagios"
      #   top.deprec.apache.reload
      # end
      
      # Control

      desc "Start Nagios"
      task :start, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios start")
      end

      desc "Stop Nagios"
      task :stop, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios stop")
      end

      desc "Restart Nagios"
      task :restart, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios restart")
      end

      desc "Reload Nagios"
      task :reload, :roles => :nagios do
        send(run_method, "/etc/init.d/nagios reload")
      end
      
      task :backup, :roles => :web do
        # not yet implemented
      end
      
      task :restore, :roles => :web do
        # not yet implemented
      end
    
    end
    
    SRC_PACKAGES[:nagios_plugins] = {
      :url => "http://prdownloads.sourceforge.net/sourceforge/nagiosplug/nagios-plugins-1.4.14.tar.gz",
      :md5sum => "a1835a48a777863ed2583de3c82446a9  nagios-plugins-1.4.14.tar.gz", 
      :configure => "./configure --with-nagios-user=#{nagios_user} --with-nagios-group=#{nagios_group};",
    }   
          
    namespace :nagios_plugins do
    
      desc "Install nagios plugins"
      task :install do
        install_deps
        create_nagios_user
        deprec2.download_src(SRC_PACKAGES[:nagios_plugins], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nagios_plugins], src_dir)        
        config_access
        install_custom
      end
      
      # allow the user to install custom plugins from RAILS_ROOT/config/nagios_plugins/plugins
      # any file there is uploaded to /usr/local/nagios/libexec and chmodded to 755
      desc "Install user plugins for nagios from config/nagios_plugins/plugins in user's project"
      task :install_custom do
        plugins_path = File.join('config', 'nagios_plugins', 'plugins')
        if File.directory?(plugins_path)
          remote_path = File.join('/', 'usr', 'local', 'nagios', 'libexec')
          Dir.new(plugins_path).entries.each do |entry|
            remote_plugin = File.join(remote_path, entry)
            plugin = File.join(plugins_path, entry)
            if File.file?(plugin)
              std.su_put File.read(plugin), remote_plugin, '/tmp', :mode => 0755
            end
          end
        end
      end

      # configure ssh + sudo for nagios:
      # * allow certain commands so nagios can do checks (killall, kill, iptables, cat) as root
      # * add nagios ssh key to authorized keys on servers to check (if the variable is set)
      desc "configure ssh + sudo access for nagios_user"
      task :config_access do
        nagios_sudo_commands.each do |command|
          deprec2.append_to_file_if_missing('/etc/sudoers', "#{nagios_user} ALL=(root) NOPASSWD:#{command}")
        end
        unless nagios_ssh_key.nil?
          sudo "mkdir -p /home/#{nagios_user}/.ssh"
          sudo "chmod 700 /home/#{nagios_user}/.ssh"
          if nagios_ssh_key
            sudo "echo '#{nagios_ssh_key}' >> /tmp/authorized_keys_file_for_nagios_user.tmp"
          end
          sudo "mv /tmp/authorized_keys_file_for_nagios_user.tmp /home/#{nagios_user}/.ssh/authorized_keys"
          sudo "chmod 600 /home/#{nagios_user}/.ssh/authorized_keys"
          sudo "chown -R nagios:nagios /home/#{nagios_user}/.ssh"
        end
      end

      # Install dependencies for nagios plugins
      task :install_deps do
        apt.install( {:base => %w(libmysqlclient15-dev)}, :stable )
      end
      
      task :create_nagios_user do
        deprec2.groupadd(nagios_group)
        deprec2.useradd(nagios_user, :group => nagios_group, :homedir => false)
        # deprec2.add_user_to_group(nagios_user, apache_user)
        deprec2.groupadd(nagios_cmd_group)
        deprec2.add_user_to_group(nagios_user, nagios_cmd_group)
        deprec2.add_user_to_group(apache_user, nagios_cmd_group)        
      end
      
      
    end
    

    namespace :nrpe do
      
      default :nrpe_enable_command_args, false # set to true to compile nrpe to accept arguments
	                                       # note that you'll need to set it before these recipes are loaded (e.g. in .caprc)
      
      SRC_PACKAGES[:nrpe] = {
        :url => "http://downloads.sourceforge.net/nagios/nrpe-2.12.tar.gz",
        :md5sum => "b2d75e2962f1e3151ef58794d60c9e97  nrpe-2.12.tar.gz", 
        :configure => "./configure --with-nagios-user=#{nagios_user} --with-nagios-group=#{nagios_group} #{ '--enable-command-args' if nrpe_enable_command_args};",
        :make => 'make all;',
        :install => 'make install-plugin; make install-daemon; make install-daemon-config;'
      }
    
      desc 'Install NRPE'
      task :install do
        install_deps
        create_nagios_user
        deprec2.download_src(SRC_PACKAGES[:nrpe], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:nrpe], src_dir)
        # XXX this should only be run on the nrpe clients
        # XXX currently it's run on the nagios server too 
        # XXX shouldn't do any harm but we should split them up later 
        deprec2.append_to_file_if_missing('/etc/services', 'nrpe            5666/tcp # NRPE')    
        config
      end
      
      task :install_deps do
        apt.install( {:base => %w(xinetd libssl-dev openssl)}, :stable )
      end
      
      task :create_nagios_user do
        deprec2.groupadd(nagios_group)
        deprec2.useradd(nagios_user, :group => nagios_group, :homedir => false)
        # deprec2.add_user_to_group(nagios_user, apache_user)
        deprec2.groupadd(nagios_cmd_group)
        deprec2.add_user_to_group(nagios_user, nagios_cmd_group)
        deprec2.add_user_to_group(apache_user, nagios_cmd_group)        
      end
      
      SYSTEM_CONFIG_FILES[:nrpe] = [
        
        {:template => 'nrpe.xinetd.erb',
         :path => "/etc/xinetd.d/nrpe",
         :mode => 0644,
         :owner => 'root:root'},
         
        {:template => 'nrpe.cfg.erb',
         :path => "/usr/local/nagios/etc/nrpe.cfg",
         :mode => 0644,
         :owner => 'nagios:nagios'}, # XXX hard coded file owner is bad...
                                    # It's done here because we aren't using 
                                    # lazy eval in hash constant.
        {:template => "check_mongrel_cluster.rb",
         :path => '/usr/local/nagios/libexec/check_mongrel_cluster.rb',
         :mode => 0755,
         :owner => 'root:root'},
         
         {:template => "check_linux_free_memory.pl",
          :path => '/usr/local/nagios/libexec/check_linux_free_memory.pl',
          :mode => 0755,
          :owner => 'root:root'}
      
      ]
      
      desc "Generate configuration file(s) for nrpe from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:nrpe].each do |file|
          deprec2.render_template(:nagios, file)
        end
      end
      
      desc "Push nrpe config files to server"
      task :config do
        deprec2.push_configs(:nagios, SYSTEM_CONFIG_FILES[:nrpe])
        # XXX should really only do this on targets
        sudo "/etc/init.d/xinetd stop"  
        sudo "/etc/init.d/xinetd start"  
      end
      
      desc "Test whether NRPE is listening on client"
      task :test_local do
        run "/usr/local/nagios/libexec/check_nrpe -H localhost"
      end
      
      desc "Test whether nagios server can query client via NRPE"
      task :test_remote, :roles => :nagios do
        target_host = Capistrano::CLI.ui.ask "target hostname"
        run "/usr/local/nagios/libexec/check_nrpe -H #{target_host}"
      end
  
    end
      
    # PNP4nagios
    # http://downloads.sourceforge.net/sourceforge/pnp4nagios/pnp-0.4.14.tar.gz?use_mirror=internode
    
    
  end
end
