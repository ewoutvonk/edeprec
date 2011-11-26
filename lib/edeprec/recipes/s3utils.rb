# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :s3utils do
      
      set :s3utils_bucket_location, 'EU'
      set :s3utils_calling_format, 'SUBDOMAIN' # used by s3sync in s3config.yml
      set :s3utils_access_key, "0123456789ABCDEFGHIJ"
      set :s3utils_secret_key, "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcd"
      set :s3utils_passphrase, "my_passphrase"
      
      SRC_PACKAGES[:s3cmd] = {
        :filename => 's3cmd-0.9.9.91.tar.gz',   
        :dir => 's3cmd-0.9.9.91',  
        :url => "http://sourceforge.net/projects/s3tools/files/s3cmd/0.9.9.91/s3cmd-0.9.9.91.tar.gz/download",
        :unpack => "tar zxf s3cmd-0.9.9.91.tar.gz;",
        :configure => 'echo > /dev/null',
        :make => 'echo > /dev/null',
        :install => 'cp -a S3 s3cmd /usr/local/bin/ ; cp s3cmd.1 /usr/local/share/man/man1/ ;'
      }

      # XXX - setting it as a class variable makes it initialize too early, making 'user' contain the wrong value! - le1t0
      def s3utils_system_config_files
        [
          {:template => "s3cfg",
           :path => "/home/#{user}/.s3cfg",
           :mode => 0644,
           :owner => "#{user}:#{user}"},
         
          {:template => "s3config.yml",
           :path => "/home/#{user}/.s3conf/s3config.yml",
           :mode => 0644,
           :owner => "#{user}:#{user}"}
        ]
      end
      
      desc "install various s3 utils"
      task :install do
        gem2.install 's3sync'
        deprec2.download_src(SRC_PACKAGES[:s3cmd], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:s3cmd], src_dir)
      end
    
      desc <<-DESC
      Generate s3utils config from template. Note that this does not
      push the config to the server, it merely generates required
      configuration files. These should be kept under source control.            
      The can be pushed to the server with the :config task.
      DESC
      task :config_gen do
        s3utils_system_config_files.each do |file|
          deprec2.render_template(:s3utils, file)
        end
      end

      desc "Push s3utils config files to server"
      task :config do
        deprec2.push_configs(:s3utils, s3utils_system_config_files)
      end
      
    end 
  end
end