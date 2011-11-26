# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :xentools do
        
      set :xentools_default_lvm, 'xendisks' # for ubuntu default, set to nil
      set :xentools_default_memory, '256Mb' # for ubuntu default, set to '128Mb'
      set :xentools_default_swap, '512Mb' # for ubuntu default, set to '128Mb'
      set :xentools_default_dist, 'hardy' # for ubuntu default, set to 'etch'
      set :xentools_default_gateway, '192.168.1.1' # for ubuntu default, set to nil
      set :xentools_default_netmask, '255.255.255.0' # for ubuntu default, set to nil
      set :xentools_default_broadcast, '192.168.1.255' # for ubuntu default, set to nil
      set :xentools_default_arch, nil # for ubuntu default, set to nil
      set :xentools_default_mirror, 'http://archive.ubuntu.com/ubuntu/' # for ubuntu default, set to 'http://ftp.us.debian.org/debian/'
      set :xentools_default_serial_device, nil # for ubuntu default, set to nil
      set :xentools_default_disk_device, 'xvda' # for ubuntu default, set to 'xvda'
      set :xentools_default_size, '4Gb' # ubuntu & deprec default
      set :xentools_default_fs, 'ext3' # ubuntu & deprec default
      set :xentools_default_image, 'sparse' # ubuntu & deprec default
      set :xentools_default_noswap, nil # ubuntu & deprec default
      set :xentools_default_dir, nil # ubuntu & deprec default      
      set :"xentools_default_install-method", 'debootstrap' # ubuntu & deprec default      
      set :"xentools_default_install-source", nil # ubuntu & deprec default      
      set :"xentools_default_copy-cmd", nil # ubuntu & deprec default      
      set :"xentools_default_debootstrap-cmd", nil # ubuntu & deprec default      
      set :"xentools_default_tar-cmd", nil # ubuntu & deprec default      
      set :xentools_default_dhcp, nil # ubuntu & deprec default      
      set :xentools_default_cache, nil # ubuntu & deprec default      
      set :xentools_default_passwd, nil # ubuntu & deprec default      
      set :xentools_default_accounts, nil # ubuntu & deprec default      
      set :xentools_default_kernel, '/boot/vmlinuz-`uname -r`' # ubuntu & deprec default      
      set :xentools_default_initrd, '/boot/initrd.img-`uname -r`' # ubuntu & deprec default      
      set :xentools_default_boot, nil # ubuntu & deprec default      
      set :xentools_default_bootloader, nil # ubuntu & deprec default, set to '/usr/bin/pygrub' for pygrub loading of VMs
      set :xentools_default_ext3_options, 'noatime,nodiratime,errors=remount-ro' # ubuntu & deprec default      
      set :xentools_default_ext2_options, 'noatime,nodiratime,errors=remount-ro' # ubuntu & deprec default      
      set :xentools_default_xfs_options, 'defaults' # ubuntu & deprec default      
      set :xentools_default_reiser_options, 'defaults' # ubuntu & deprec default      
      set :xentools_enable_modules, false # if true, modules will be set to /lib/modules/`uname -r`, for ubuntu default, set to false
      set :xentools_enable_eth0_tx, true # for ubuntu default, set to false

      set :xentools_custom_commands_pre, nil # should be a string
      set :xentools_custom_commands_post, nil # should be a string
      set :xentools_no_utc, false
      set :xentools_enable_sudo_in_sudoers, false
      set :xentools_deploy_user, nil
      set :xentools_deploy_group, nil
      set :xentools_copy_localtime, false
      set :xentools_disable_hwclock, false
      set :xentools_dist_upgrade, false

      desc "Install xen-tools"
      task :install, :roles => :dom0 do
        install_deps
        top.deprec.xentools.fix_config
      end

      task :install_deps, :roles => :dom0 do
        apt.install( {:base => %w(xen-tools libexpect-perl)}, :stable )
      end
      
      task :fix_config, :roles => :dom0 do
        sudo "perl -p -i -e 's/^#\\//#!\\//;' /usr/lib/xen-tools/gutsy.d/31-ubuntu-setup"
        sudo "perl -p -i -e 's/^#\\//#!\\//; s/^prefix=\\$i/prefix=\\$1/' /usr/lib/xen-tools/gutsy.d/100-ubuntu-setup"
        run "[ -e /etc/xen-tools/xen-tools.conf.bak ] || sudo cp /etc/xen-tools/xen-tools.conf /etc/xen-tools/xen-tools.conf.bak"
        sudo "perl -p -i -e 's/^\\s*#\\s*[^\\n]*\\n//' /etc/xen-tools/xen-tools.conf"
        sudo "perl -p -i -e 's/^[^ \\t]*\\n//' /etc/xen-tools/xen-tools.conf"
      end
      
      SYSTEM_CONFIG_FILES[:xentools] = [

        {:template => "xm.tmpl.erb",
         :path => '/etc/xen-tools/xm.tmpl',
         :mode => 0644,
         :owner => 'root:root'},
         
        # added script for user adjustments to debootstrap results
        {:template => "98-custom.erb",
         :path => '/usr/lib/xen-tools/hardy.d/98-custom',
         :mode => 0755,
         :owner => 'root:root'},

        # added script for having /dev/pts mounted during running of hooks
        {:template => "99-devpts-umount.erb",
         :path => '/usr/lib/xen-tools/hardy.d/99-devpts-umount',
         :mode => 0755,
         :owner => 'root:root'},

        # added script for having /dev/pts mounted during running of hooks
        {:template => "01-mount-devpts.erb",
         :path => '/usr/lib/xen-tools/hardy.d/01-mount-devpts',
         :mode => 0755,
         :owner => 'root:root'},

        # added script for auto updating of /boot/grub/menu.lst in xenU VM
        {:template => "update-grub-xenu.example.erb",
         :path => '/usr/local/share/xen-tools/update-grub-xenu.example',
         :mode => 0755,
         :owner => 'root:root'},

        {:template => "kernel-img.conf.example.erb",
         :path => '/usr/local/share/xen-tools/kernel-img.conf.example',
         :mode => 0755,
         :owner => 'root:root'}
      ]
      
      desc "Generate configuration file(s) for xen-tools from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:xentools].each do |file|
          deprec2.render_template(:xentools, file)
        end
      end

      desc "Push xen-tools config files to server"
      task :config, :roles => :dom0 do
        deprec2.push_configs(:xentools, SYSTEM_CONFIG_FILES[:xentools])
        # remove settings from xen-tools.conf in order to re-enable them later on (if set)
        sudo "cp /etc/xen-tools/xen-tools.conf #{tmpfile = Time.now.strftime("/tmp/xen-tools.conf.%Y%m%d%H%M%S")}"
        sudo "chmod 666 #{tmpfile}"
        [ :lvm, :memory, :swap, :dist, :gateway, :netmask, :broadcast, :arch, :mirror, :serial_device, :disk_device, :size, :fs, :image, :noswap, :dir, :"install-method", :"install-source", :"copy-cmd", :"debootstrap-cmd", :"tar-cmd", :dhcp, :cache, :passwd, :accounts, :kernel, :initrd, :boot, :bootloader, :ext3_options, :ext2_options, :xfs_options, :reiser_options, :modules ].each do |v|
          sudo "perl -p -i -e 's/^\\s*#{v}\\s*=[^\\n]*\\n//' #{tmpfile}"
        end
        [ :lvm, :memory, :swap, :dist, :gateway, :netmask, :broadcast, :arch, :mirror, :serial_device, :disk_device, :size, :fs, :image, :noswap, :dir, :"install-method", :"install-source", :"copy-cmd", :"debootstrap-cmd", :"tar-cmd", :dhcp, :cache, :passwd, :accounts, :kernel, :initrd, :boot, :bootloader, :ext3_options, :ext2_options, :xfs_options, :reiser_options ].each do |v|
          run "echo '#{v} = #{send("xentools_default_#{v}".to_sym)}' >> #{tmpfile}" if send("xentools_default_#{v}".to_sym)
        end
        run "echo 'modules = /lib/modules/`uname -r`' >> #{tmpfile}" if xentools_enable_modules
        sudo "chmod 644 #{tmpfile}"
        sudo "mv #{tmpfile} /etc/xen-tools/xen-tools.conf"
        # domU -> domU networking is screwy
        if xentools_enable_eth0_tx
          sudo "perl -p -i -e 's/^(\\s*)#(\\s*)(post-up\\s*ethtool\\s*-K\\s*eth0\\s*tx\\s*off)/\$1\$2\$3/' /usr/lib/xen-tools/gutsy.d/40-setup-networking"
        else
          sudo "perl -p -i -e 's/^(\\s*)(post-up\\s*ethtool\\s*-K\\s*eth0\\s*tx\\s*off)/#\$1\$2/' /usr/lib/xen-tools/gutsy.d/40-setup-networking"
        end
      end
      
    end
    
  end
end