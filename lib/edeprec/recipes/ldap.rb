# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :ldap do

      # set(:ldap_base_dn) { 'dc='+domain.split('.').join(',dc=') }
      # set(:ldap_organization_name) { domain }
      # set :ldap_password, '{SSHA}eO3vX5G/dpiSIrPye8oJAz2DOcgy5N3f' # 'admin' encrypted

      desc "Install ldap"
      task :install, :roles => :db do
        install_deps
        config
        activate
      end

      task :install_deps, :roles => :db do
        apt.install( {:base => %w(slapd phpldapadmin ldap-utils)}, :stable )
      end

      desc 'Enable ldap start scripts on server.'
      task :activate, :roles => :db do
        send(run_method, "update-rc.d slapd defaults")
      end

      desc 'Disable ldap start scripts on server.'
      task :deactivate, :roles => :db do
        send(run_method, "update-rc.d -f slapd remove")
      end

      desc "Start ldap"
      task :start, :roles => :db do
        send(run_method, "/etc/init.d/slapd start")
      end

      desc "Stop ldap"
      task :stop, :roles => :db do
        send(run_method, "/etc/init.d/slapd stop")
      end

      desc "Restart ldap"
      task :restart, :roles => :db do
        send(run_method, "/etc/init.d/slapd restart")
      end

      desc "Reload ldap"
      task :reload, :roles => :db do
        top.deprec.ldap.restart
      end
    end 
  end
end