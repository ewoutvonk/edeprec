# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :amcc_3ware do
      
      desc "Install 3ware management tools"
      task :install, :roles => :storage_backend do
        sudo "sh -c 'cd /tmp ; wget http://www.3ware.com/download/Escalade9690SA-Series/9.5.3/tw_cli-linux-x86_64-9.5.3.tgz'"
        sudo "sh -c 'cd /tmp ; wget http://www.3ware.com/download/Escalade9690SA-Series/9.5.3/tw_cli-linux-x86-9.5.3.tgz'"
        
        sudo "sh -c 'cd /opt ; mkdir -p 3ware_tools/x86_64 ; cd 3ware_tools/x86_64 ; tar zxf /tmp/tw_cli-linux-x86_64-9.5.3.tgz'"
        sudo "sh -c 'cd /opt ; mkdir -p 3ware_tools/i686 ; cd 3ware_tools/i686 ; tar zxf /tmp/tw_cli-linux-x86-9.5.3.tgz ; ln -sf /opt/3ware_tools/i686 /opt/3ware_tools/i386'"
        sudo "ln -sf /opt/3ware_tools/$(uname -m) /opt/3ware"
        
        sudo "chmod 755 /opt/3ware/tw_cli"
        sudo "ln -sf /opt/3ware/tw_cli /usr/local/bin/"
      end

    end
  end
end