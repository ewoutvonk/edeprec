# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :xen do
      
      # define images to create, i.e.:
      # set :xen_images, [
      #   {
      #     :hostname => 'appserver',
      #     :lvm => 'mylvm',
      #     :gateway => '10.0.0.1',
      #     :netmask => '255.255.0.0',
      #     :size => '15Gb',
      #     :memory => '1Gb',
      #     :swap => '2Gb',
      #     :ip => '10.0.2.1',
      #     :mac => '00:16:3e:00:00:01',
      #     :vcpus => 3, # specify amount of vcpus to use, this will be put in the VM config in /etc/xen/
      #     :cpus => '1,3,6', # specify list of cpus to use, this will be put in the VM config in /etc/xen/
      #     :arch => 'i386' # specify to create an i386 VM if you have a x86_64 host for example; optional.
      #   },
      #   {
      #     :hostname => 'db',
      #     :lvm => 'mylvm',
      #     :gateway => '10.0.0.1',
      #     :netmask => '255.255.0.0',
      #     :size => '15Gb',
      #     :memory => '1Gb',
      #     :swap => '2Gb',
      #     :ip => '10.0.2.1',
      #     :mac => '00:16:3e:00:00:01',
      #     :vcpus => 3, # specify amount of vcpus to use, this will be put in the VM config in /etc/xen/
      #     :cpus => '1,3,6', # specify list of cpus to use, this will be put in the VM config in /etc/xen/
      #   } 
      # ]
      # Options in the hash above will be sent as is to the xen-create-image command, any options that xen-create-image
      # accepts you can add there. Additionally the options :vcpus and :cpus are accepted, which are stripped out before
      # calling xen-create-image, and put into the resulting xen VM configuration file.
      set :xen_images, []            
      
      set :xen_volume_group_name, 'xendisks'
      # Config variables for migration
      default(:xen_slice) { Capistrano::CLI.ui.ask("Slice name") }
      default(:xen_old_host) { Capistrano::CLI.ui.ask("Old Xen host") }
      default(:xen_new_host) { Capistrano::CLI.ui.ask("New Xen host") }
      set(:xen_disk_size) { Capistrano::CLI.ui.ask("Disk size (GB)") }
      set(:xen_swap_size) { Capistrano::CLI.ui.ask("Swap size (GB)") }
      
      # ref: http://www.eadz.co.nz/blog/article/xen-gutsy.html
      
      desc "Install Xen"
      task :install, :roles => :dom0 do
        install_deps
        top.deprec.xentools.install
        disable_apparmour
        # enable_hardy_domu Should only be run on gutsy
        initial_config
      end
      
      task :install_deps, :roles => :dom0 do
        # for amd64 version of ubuntu 7.10
        # apt.install( {:base => %w(linux-image-xen bridge-utils libxen3.1 python-xen-3.1 xen-docs-3.1 xen-hypervisor-3.1 xen-ioemu-3.1 xen-tools xen-utils-3.1 lvm2)}, :stable )
        # alternatively, for x86 version of ubuntu:
        # apt-get install ubuntu-xen-server libc6-xen lvm2    
        # apt.install( {:base => %w(ubuntu-xen-server libc6-xen lvm2)}, :stable )
        apt.install( {:base => %w(ubuntu-xen-server lvm2)}, :stable )
        
      end
      
      task :disable_apparmour, :roles => :dom0 do
        sudo '/etc/init.d/apparmor stop'
        sudo 'update-rc.d -f apparmor remove'
      end
      
      # task :disable_tls, :roles => :dom0 do
      #   sudo 'mv /lib/tls /lib/tls.disabled'
      # end
      
      SYSTEM_CONFIG_FILES[:xen] = [
                
        # {:template => "xend-config.sxp.erb",
        # :path => '/etc/xen/xend-config.sxp',
        # :mode => 0644,
        # :owner => 'root:root'},
        #  
        # {:template => "xendomains.erb",
        #  :path => '/etc/default/xendomains',
        #  :mode => 0755,
        #  :owner => 'root:root'},
        #  
        # This gives you a second network bridge on second ethernet device  
        {:template => "network-bridge-wrapper",
         :path => '/etc/xen/scripts/network-bridge-wrapper',
         :mode => 0755,
         :owner => 'root:root'},
        #  
        # # Bugfix for gutsy - xendomains fails to shut down domains on system shutdown
        # {:template => "xend-init.erb",
        #  :path => '/etc/init.d/xend',
        #  :mode => 0755,
        #  :owner => 'root:root'}
                 
      ]
      
      desc "Push Xen config files to server"
      task :initial_config, :roles => :dom0 do
        # Non-standard! We're pushing these straight out
        SYSTEM_CONFIG_FILES[:xen].each do |file|
          deprec2.render_template(:xen, file.merge(:remote => true))
        end     
      end
      
      desc "Generate configuration file(s) for Xen from template(s)"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:xen].each do |file|
          deprec2.render_template(:xen, file)
        end
      end
      
      desc "Push Xen config files to server"
      task :config, :roles => :dom0 do
        deprec2.push_configs(:xen, SYSTEM_CONFIG_FILES[:xen])
      end
      
      # Create new virtual machine
      # xen-create-image --force --ip=192.168.1.31 --hostname=x1 --mac=00:16:3E:11:12:31
      
      # Start a virtual image (and open console to it)
      # xm create /etc/xen/x1.cfg -c
      
      desc "Start Xen"
      task :start, :roles => :dom0 do
        send(run_method, "/etc/init.d/xend start")
      end

      desc "Stop Xen"
      task :stop, :roles => :dom0 do
        send(run_method, "/etc/init.d/xend stop")
      end

      desc "Restart Xen"
      task :restart, :roles => :dom0 do
        send(run_method, "/etc/init.d/xend restart")
      end

      desc "Reload Xen"
      task :reload, :roles => :dom0 do
        send(run_method, "/etc/init.d/xend reload")
      end
      
      task :list, :roles => :dom0 do
        sudo "xm list"
      end
      
      task :info, :roles => :dom0 do
        sudo "xm info"
      end

      desc "Migrate a slice on one Xen host to another. Slice is stopped, disk is tar'd up and transferred to new host."
      task :migrate do

        # Get user input for these values
        xen_old_host && xen_new_host && xen_disk_size && xen_swap_size && xen_slice

        copy_disk
        copy_slice_config
        create_lvm_disks
        build_slice_from_tarball
      end

      task :copy_disk do
        mnt_dir = "/mnt/#{xen_slice}-disk"
      	tarball = "/tmp/#{xen_slice}-disk.tar"
      	lvm_disk = "/dev/#{xen_volume_group_name}/#{xen_slice}-disk"

        # Shutdown slice
      	sudo "xm list | grep #{xen_slice} && #{sudo} xm shutdown #{xen_slice} && sleep 10; exit 0", :hosts => xen_old_host

      	# Tar up disk partition
      	sudo "test -d #{mnt_dir} || #{sudo} mkdir #{mnt_dir}; exit 0", :hosts => xen_old_host
      	sudo "mount | grep #{mnt_dir} || #{sudo} mount -t auto #{lvm_disk} #{mnt_dir}; exit 0", :hosts => xen_old_host
      	sudo "sh -c 'cd #{mnt_dir} && tar cfp #{tarball} *'", :hosts => xen_old_host
        sudo "umount #{mnt_dir}", :hosts => xen_old_host
        sudo "rmdir #{mnt_dir}", :hosts => xen_old_host

      	# start slice again if necessary
      	# xm create ${SLICE}.cfg

      	# copy to other server
      	run "scp #{tarball} #{xen_new_host}:/tmp/", :hosts => xen_old_host

      	# clean up tarball
      	sudo "rm #{tarball}", :hosts => xen_old_host
      end

      task :copy_slice_config do
        run "scp /etc/xen/#{xen_slice}.cfg #{xen_new_host}:", :hosts => xen_old_host
        sudo "test -f /etc/xen/#{xen_slice}.cfg || #{sudo} mv #{xen_slice}.cfg /etc/xen/", :hosts => xen_new_host
      end

      task :create_lvm_disks do
        xen_new_host
        # create lvm disks on new host
        disks = {"#{xen_slice}-disk" => xen_disk_size, "#{xen_slice}-swap" => xen_swap_size}
        disks.each { |disk, size|
          puts "Creating #{disk} (#{size} GB)"
          sudo "lvcreate -L #{size}G -n #{disk} #{xen_volume_group_name}", :hosts => xen_new_host
          sudo "mkfs.ext3 /dev/#{xen_volume_group_name}/#{disk}", :hosts => xen_new_host
        }
      end

      task :build_slice_from_tarball do
        mnt_dir = "/mnt/#{xen_slice}-disk"
      	tarball = "/tmp/#{xen_slice}-disk.tar"
      	lvm_disk = "/dev/#{xen_volume_group_name}/#{xen_slice}-disk"

      	# untar archive into lvm disk
      	sudo "test -d #{mnt_dir} || #{sudo} mkdir #{mnt_dir}; exit 0", :hosts => xen_new_host
      	sudo "mount | grep #{mnt_dir} || #{sudo} mount -t auto #{lvm_disk} #{mnt_dir}; exit 0", :hosts => xen_new_host
      	sudo "sh -c 'cd #{mnt_dir} && tar xf #{tarball}'", :hosts => xen_new_host
        sudo "umount #{mnt_dir}", :hosts => xen_new_host
        sudo "rmdir #{mnt_dir}", :hosts => xen_new_host
      end
      
      desc "Enable hardy heron domU's on gutsy dom0. (Note required on hardy)"
      task :enable_hardy_domu, :roles => :dom0 do
        # Note, hardy keeps debootrap in /usr/share/debootstrap/scripts/
        # create debootstrap symlink
        sudo "ln -sf /usr/lib/debootstrap/scripts/gutsy /usr/lib/debootstrap/scripts/hardy"
        # link xen-tools hooks
        sudo "ln -sf /usr/lib/xen-tools/edgy.d /usr/lib/xen-tools/hardy.d"
      end
      
      task :touch_hwclock do
        sudo "touch /etc/init.d/hwclock.sh"
      end
      
      # create new xen images, based on configuration in :xen_images capistrano variable (see above)
      # a subselection of images can be created by using the ONLY=".." environment variable:
      #
      # $ cap deprec:xen:create_images ONLY="appserver"
      #
      # The images to create are matched on the :hostname value in :xen_images
      desc "Create Xen images"
      task :create_images, :roles => :dom0 do
        do_xen_images = (ENV['ONLY'] || '').split(',')
        xen_images_list = {}
        find_servers.collect { |server| server.host }.each do |host|
          scope host do
            xen_images_list[host] = (xen_images || []).collect do |xen_image|
                args = ([xen_image[:hostname]] + xen_image.collect do |k,v|
                  "--#{k}=#{v}" unless [ :vcpus, :cpus ].include?(k)
                end.compact).join(' ')
                cpus = [xen_image[:hostname], xen_image[:vcpus] || 1, xen_image[:cpus]].compact.join(' ')
                do_xen_images.size == 0 || do_xen_images.include?(xen_image[:hostname]) ? [ args, cpus ] : nil
              end.compact
          end
        end

        std.su_put "", tmpfile_xi = "/tmp/xen_images.#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", '/tmp/', :mode=>0644, :proc => Proc.new { |from, host|
          image_list = xen_images_list[host].collect { |ar| ar[0] }.join("\n").strip
          image_list.empty? ? image_list : image_list + "\n"
        }
        std.su_put "", tmpfile_xc = "/tmp/xen_cpus.#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", '/tmp/', :mode=>0644, :proc => Proc.new { |from, host|
          image_list = xen_images_list[host].collect { |ar| ar[1] }.join("\n").strip
          image_list.empty? ? image_list : image_list + "\n"
        }

        run <<-EOF
          cat #{tmpfile_xi} | while read xen_image opts ; do {
            [ -e /etc/xen/${xen_image}.cfg -o -z "${xen_image}" ] || echo sudo /usr/bin/xen-create-image ${opts} ;
            [ -e /etc/xen/${xen_image}.cfg -o -z "${xen_image}" ] || sudo /usr/bin/xen-create-image ${opts} ;
          } ; done
EOF
        run <<-EOF
          cat #{tmpfile_xc} | while read xen_image vcpus cpus ; do {
            tmpfile="/tmp/.${xen_image}.xen_config.$(date +"%Y%m%d%H%M%S").txt" ;
            [ -z "${vcpus}" -a -z "${cpus}" ] || cat /etc/xen/${xen_image}.cfg > ${tmpfile} ;
            [ -z "${vcpus}" -a -z "${cpus}" ] || echo >> ${tmpfile} ;
            [ -z "${vcpus}" ] || echo "vcpus = '${vcpus}'" >> ${tmpfile} ;
            [ -z "${cpus}" ] || echo "cpus = '${cpus}'" >> ${tmpfile} ;
            [ -z "${vcpus}" -a -z "${cpus}" ] || sudo mv ${tmpfile} /etc/xen/${xen_image}.cfg ;
          } ; done
EOF
        sudo "rm -f #{tmpfile_xi} #{tmpfile_xc}"
        top.deprec.xen.auto_start_images
      end

      # Same explanation as for create_images, but in this case for registering images to be auto-started at host sys boot up
      desc "Make links for xen image configs to be started automatically"
      task :auto_start_images, :roles => :dom0 do
        do_xen_images = (ENV['ONLY'] || '').split(',')
        xen_images_list = {}
        find_servers.collect { |server| server.host }.each do |host|
          scope host do
            xen_images_list[host] = (xen_images || []).collect do |xen_image|
                do_xen_images.size == 0 || do_xen_images.include?(xen_image[:hostname]) ? xen_image[:hostname] : nil
              end.compact.join("\n").strip
          end
        end

        std.su_put "", tmpfile = "/tmp/xen_images.#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", '/tmp/', :mode=>0644, :proc => Proc.new { |from, host|
          xen_images_list[host].empty? ? xen_images_list[host] : xen_images_list[host] + "\n"
        }

        run <<-EOF
          cat #{tmpfile} | while read xen_image ; do {
            [ -z "${xen_image}" ] || sudo ln -nsf /etc/xen/${xen_image}.cfg /etc/xen/auto/${xen_image}.cfg ;
          } ; done
EOF
        sudo "rm -f #{tmpfile}"
      end

      # Same explanation as for create_images, but in this case for unregistering images to be auto-started at host sys boot up
      desc "Make links for xen image configs to be started automatically"
      task :undo_auto_start_images, :roles => :dom0 do
        do_xen_images = (ENV['ONLY'] || '').split(',')
        xen_images_list = {}
        find_servers.collect { |server| server.host }.each do |host|
          scope host do
            xen_images_list[host] = (xen_images || []).collect do |xen_image|
                do_xen_images.size == 0 || do_xen_images.include?(xen_image[:hostname]) ? xen_image[:hostname] : nil
              end.compact.join("\n").strip
          end
        end

        std.su_put "", tmpfile = "/tmp/xen_images.#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", '/tmp/', :mode=>0644, :proc => Proc.new { |from, host|
          xen_images_list[host].empty? ? xen_images_list[host] : xen_images_list[host] + "\n"
        }

        run <<-EOF
          cat #{tmpfile} | while read xen_image ; do {
            [ -z "${xen_image}" ] || sudo rm -f /etc/xen/auto/${xen_image}.cfg ;
          } ; done
EOF
        sudo "rm -f #{tmpfile}"
      end

      # Same explanation as for create_images, but in this case for starting images
      desc "Start Xen images"
      task :start_images, :roles => :dom0 do
        do_xen_images = (ENV['ONLY'] || '').split(',')
        xen_images_list = {}
        find_servers.collect { |server| server.host }.each do |host|
          scope host do
            xen_images_list[host] = (xen_images || []).collect do |xen_image|
                do_xen_images.size == 0 || do_xen_images.include?(xen_image[:hostname]) ? xen_image[:hostname] : nil
              end.compact.join("\n").strip
          end
        end

        std.su_put "", tmpfile = "/tmp/xen_images.#{Time.now.strftime("%Y%m%d%H%M%S")}.txt", '/tmp/', :mode=>0644, :proc => Proc.new { |from, host|
          xen_images_list[host].empty? ? xen_images_list[host] : xen_images_list[host] + "\n"
        }

        run <<-EOF
          cat #{tmpfile} | while read xen_image ; do {
            [ -z "${xen_image}" ] || sudo /usr/sbin/xm create ${xen_image}.cfg 1>/dev/null ;
          } ; done
EOF
        sudo "rm -f #{tmpfile}"
      end

      # show configs of all registered VMs on host system, use grep to get certain info fields
      desc "Show configs of all installed VMs"
      task :show_vm_configs do
        all_data = ""
        sudo "grep -v '^$' /etc/xen/*.cfg | awk -v h=$(hostname) '{ print h\":\"$0; }'" do |channel, stream, data|
          all_data += data.strip
        end
        datalines = all_data.split("\n")
        datahashes = datalines.collect { |line| a = line.split(":", 3) ; { :host => a[0], :vm => a[1].gsub(/^\/etc\/xen\//, '').gsub(/\.cfg$/, ''), :line => a[2] } }
        datahashes2 = {}
        datahashes.each do |dh|
          datahashes2[dh[:host]] ||= {}
          datahashes2[dh[:host]][dh[:vm]] ||= ""
          datahashes2[dh[:host]][dh[:vm]] << dh[:line] + "\n" unless dh[:line] =~ /^(\s*|\s*#.*)$/
        end
        datahashes2.each do |host, vm_files|
          vm_files.each do |vm, file|
            puts "#{host}:#{vm}"
            puts file.gsub(/\[\s+([^\s\]]+)\s+([^\s\]]+)\s+\]/, '[\1\2]').gsub(/(^|\n)(\s*)([^\s=]+)(\s*)=(\s*)([^\s=].*[^\s=]?)(\s*)(\n|$)/, '\1\3=\6\8')
          end
        end
      end
      
    end
    
  end
end

# Add support for intrepid and jaunty guests to hardy host
#
# root@x1:/usr/share/debootstrap/scripts# ln -s gutsy jaunty
# root@x1:/usr/share/debootstrap/scripts# ln -s gutsy intrepid
#
# root@x1:/usr/lib/xen-tools# ln -s edgy.d intrepid.d
# root@x1:/usr/lib/xen-tools# ln -s edgy.d jaunty.d

# Stop the 'incrementing ethX problem'
#
# Ubuntu stores the MAC addresses of the NICs it sees. If you change an ethernet card (real or virtual)
# it will assign is a new ethX address. That's why you'll sometimes find eth2 but no eth1.
# Your domU's should have a MAC address assigned in their config file but if you come across this problem, 
# fix it with this:
#
# sudo rm /etc/udev/rules.d/70-persistent-net.rules



# ubuntu bugs
# 
# check if they're fixed in hardy heron

#    1: domains are not shut down on system shutdown
#    cause: order that init scripts get called
#    fix: call /etc/init.d/xendomains from /etc/init.d/xend script

      # stop)
      # /etc/init.d/xendomains stop # make sure domains are shut down
      # xend stop
      # ;;
      
#
# Install xen on ubuntu hardy
#
# ref: http://www.howtoforge.com/ubuntu-8.04-server-install-xen-from-ubuntu-repositories
#

# Install Xen packages 
# apt-get install ubuntu-xen-server
  #
  # Installs these:
  # 
  # binutils binutils-static bridge-utils debootstrap libasound2 libconfig-inifiles-perl libcurl3 libdirectfb-1.0-0 libsdl1.2debian
  # libsdl1.2debian-alsa libtext-template-perl libxen3 libxml2 linux-image-2.6.24-16-xen linux-image-xen
  # linux-restricted-modules-2.6.24-16-xen linux-restricted-modules-common linux-restricted-modules-xen
  # linux-ubuntu-modules-2.6.24-16-xen linux-xen nvidia-kernel-common python-dev python-xen-3.2 python2.5-dev ubuntu-xen-server
  # xen-docs-3.2 xen-hypervisor-3.2 xen-tools xen-utils-3.2
  
  # before/after 'uname -a'
  #
  # Linux bb 2.6.24-16-server #1 SMP Thu Apr 10 13:15:38 UTC 2008 x86_64 GNU/Linux
  # Linux bb 2.6.24-16-xen #1 SMP Thu Apr 10 14:35:03 UTC 2008 x86_64 GNU/Linux
# 
# Stop apparmor # XXX investigate why
# /etc/init.d/apparmor stop
# update-rc.d -f apparmor remove

# mkdir /home/xen

# edit /etc/xen-tools/xen-tools.cfg

# create image with xen-tools
# xen-create-image --hostname=x1 --size=2Gb --swap=256Mb --ide --ip=192.168.1.51 --memory=256Mb --install-method=debootstrap --dist=hardy 

# update /etc/xen/<domain>.cfg
#
# disk        = [
              #     'tap:aio:/home/xen/domains/xen1.example.com/swap.img,hda1,w',
              #     'tap:aio:/home/xen/domains/xen1.example.com/disk.img,hda2,w',
              # ] 
