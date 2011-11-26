# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

def rvm_command(rvm_multi_user)
  rvm_multi_user ? "/usr/local/rvm/bin/rvm" : "~/.rvm/bin/rvm"
end

def rvm_install_ruby(rvm_multi_user, ruby, env_opts = "", configure_opts = "")
  run "#{env_opts}#{rvm_command(rvm_multi_user)} --reconfigure #{configure_opts} --force install #{ruby}"
end

def rvm_install_i386_ruby(rvm_multi_user, ruby)
  rvm_install_ruby(ruby, "CFLAGS='-m32' CXXFLAGS='-m32' LDFLAGS='-m32'", "--configure --host=i686-pc-linux,--target=i686-pc-linux,--build=i686-pc-linux")
end

def convert_rubies_to_deps(base_deps_defs, extended_deps_defs = {})
  rvm_support_ruby_types = (rvm_rubies + rvm_i386_rubies).uniq.map(&:to_s).map do |ruby|
    if ruby =~ /^jruby-head$/
      :jruby_head
    elsif ruby =~ /^jruby-/
      :jruby
    elsif ruby =~ /^rbx-/
      :rbx
    elsif ruby =~ /^ree-/
      :mri_ree
    elsif ruby =~ /^ironruby$/
      :ironruby
    elsif ruby =~ /-head$/
      :ruby_head
    else
      :mri_ree
    end
  end.uniq
    
  base_deps = base_deps_defs.select { |k,v| rvm_support_ruby_types.include?(k) || k == :base }.values.flatten
  extended_deps = extended_deps_defs.select { |k,v| rvm_support_ruby_types.include?(k) || k == :base }.values.flatten
  
  (base_deps + extended_deps).uniq
end

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :ubuntu do
    namespace :rvm do
      
      # First x86_64 ruby will be set as default, or first i386 ruby if there are no x86_64 ones defined,
      # if rvm_default_ruby is nil
      set :rvm_i386_rubies, [] # i386/32-bit rubies
      set :rvm_rubies, [ '1.9.2' ] # x86_64/64-bit rubies
      set :rvm_default_ruby, nil
      set :rvm_multi_user, true
      set :rvm_version, "latest"
      set :rvm_disable_project_rvmrcs_system_wide, true
      set :rvm_disable_project_rvmrcs_for_user, true
      # rvm_gems can be:
      # - A string or symbol : the gem with that name will be installed for all rubies, no gemsets will be created
      # - An array : all gems in the array will be installed for all rubies, no gemsets will be created
      # - A hash : the keys denote rubies to install gems for, where the values can each be:
      #   - A string or symbol : the gem with that name will be installed for this ruby, no gemsets will be created
      #   - An array : all gems in the array will be installed for this ruby, no gemsets will be created
      #   - A hash : the keys denote names of gemsets to create or update, where the values can each be:
      #     - A string or symbol : the gem with that name will be installed for this ruby and gemset
      #     - An array : all gems in the array will be installed for this ruby and gemset
      # NOTE: the outer hash in rvm_gems can also contain a key named 'all'. In this case one can specify gemsets to
      # create or update for all rubies at once.
      set :rvm_gems, %w(bundler)
      
      RVM_UBUNTU_DEPS = {
        :base => %w(curl),
        :ruby_head => %(subversion),
        :mri_ree => %w(build-essential bison openssl git-core zlib1g zlib1g-dev libssl-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev autoconf libc6-dev ncurses-dev automake libtool patch),
        :jruby => %w(g++ openjdk-6-jre-headless),
        :jruby_head => %w(ant openjdk-6-jdk),
        :ironruby => %w(mono-2.0-devel),
        :rbx => []
      }
      
      desc "Install Rvm"
      task :install do
        install_deps
        install_rvm
        install_rubies
        install_gems
        set_default_ruby
      end
      
      task :install_deps do
        apt.install( {:base => convert_rubies_to_deps(RVM_UBUNTU_DEPS) }, :stable )
      end
      
      task :install_rvm do
        call_method = rvm_multi_user ? "sudo" : ""
        run "curl -s https://raw.github.com/wayneeseguin/rvm/master/binscripts/rvm-installer -o rvm-installer ; chmod +x rvm-installer ; #{call_method} ./rvm-installer --version #{rvm_version}"
        if rvm_multi_user
          run "sudo usermod -a -G rvm #{user}"
          deprec2.teardown_connections # to make sure the addition of the user to the group is effective with the next call
        else
          enable_single_user_rvm
        end
        set_project_rvmrcs
      end
      
      desc "install gems"
      task :install_gems do
        rvm_gem_list = if rvm_gems.is_a?(String) || rvm_gems.is_a?(Symbol) || rvm_gems.is_a?(Array)
          { "all" => { "global" => [ rvm_gems ].flatten.map(&:to_s) } }
        elsif rvm_gems.is_a?(Hash)
          tmp_list = {}
          rvm_gems.each do |ruby, gems_or_gem_sets|
            if gems_or_gem_sets.is_a?(Hash)
              gems_or_gem_sets.each do |gem_set, gems|
                tmp_list[key] ||= {}
                tmp_list[key][gem_set] = [gems].flatten.map(&:to_s)
              end
            else
              tmp_list[key] = { "global" => [gems_or_gem_sets].flatten.map(&:to_s) }
            end
          end
          tmp_list
        else
          {}
        end
        
        rvm_gem_list.each do |ruby, gem_sets|
          gem_sets.each do |gem_set, gems|
            gem_set_ident = gem_set.to_s == "global" ? "" : "@#{gem_set}"
            unless gem_set.to_s == "global"
              run "#{rvm_command(rvm_multi_user)} #{ruby} do #{rvm_command(rvm_multi_user)} gemset create #{gem_set}"
            end
            run "#{rvm_command(rvm_multi_user)} #{ruby}#{gem_set_ident} do gem install #{gems.join(' ')}"
          end
        end
        
      end
      
      task :enable_single_user_rvm do
        deprec2.comment_line('~/.bashrc', '[^#]+&& return.*')
        deprec2.append_to_file_if_missing('~/.bashrc', "[[ -s \\$HOME/.rvm/scripts/rvm ]] && . \\$HOME/.rvm/scripts/rvm")
      end
      
      desc "Set project rvmrcs"
      task :set_project_rvmrcs do
        if rvm_disable_project_rvmrcs_system_wide
          deprec2.append_to_file_if_missing('/etc/rvmrc', "export rvm_project_rvmrc=0")
        else
          deprec2.remove_line('/etc/rvmrc', "export rvm_project_rvmrc=0")
        end
        if rvm_disable_project_rvmrcs_for_user
          deprec2.append_to_file_if_missing('~/.rvmrc', "export rvm_project_rvmrc=0")
        else
          deprec2.remove_line('~/.rvmrc', "export rvm_project_rvmrc=0")
        end
      end
      
      desc "install selected rubies with rvm"
      task :install_rubies do
        install_x86_64_rubies
        install_i386_rubies
      end
      
      task :install_x86_64_rubies do
        rvm_rubies.each do |ruby| rvm_install_ruby(rvm_multi_user, ruby) end
      end

      task :install_i386_rubies do
        rvm_i386_rubies.each do |ruby| rvm_install_i386_ruby(rvm_multi_user, ruby) end
      end
      
      desc "Set default ruby"
      task :set_default_ruby do
        default_ruby = rvm_default_ruby || rvm_rubies.first || rvm_i386_rubies.first || "system"
        run "#{rvm_command(rvm_multi_user)} use --default #{default_ruby}"
      end
      
    end
  end
end