# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :tsung do

      SRC_PACKAGES[:tsung] = {
          :md5sum => 'ca4fbde35a5b661ff1eabcc2bdc7b5ee  tsung-1.2.1.tar.gz',
          :filename => 'tsung-1.2.1.tar.gz',   
          :dir => 'tsung-1.2.1',  
          :url => "http://www.process-one.net/downloads/tsung/1.2.1/tsung-1.2.1.tar.gz",
          :unpack => "tar zxf tsung-1.2.1.tar.gz;",
          :configure => %w(
            ./configure
            ;
            ).reject{|arg| arg.match '#'}.join(' '),
          :make => 'make;',
          :install => 'make install;'
        }

      desc "Install tsung"
      task :install, :roles => :ground_zero do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:tsung], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:tsung], src_dir)
      end

      task :install_deps, :roles => :ground_zero do
        apt.install( {:base => %w(erlang gnuplot-nox libtemplate-perl libhtml-template-perl libhtml-template-expr-perl)}, :stable )
      end


      SYSTEM_CONFIG_FILES[:tsung] = [

        {:template => 'tsung.xml.erb',
          :path => '/home/tl/.tsung/tsung.xml',
          :mode => 0644,
          :owner => 'root:root'}
      ]

      desc "Generate tsung config from template."
      task :config_gen do
        SYSTEM_CONFIG_FILES[:tsung].each do |file|
          deprec2.render_template(:tsung, file)
        end
      end

      desc "Push tsung config files to server"
      task :config, :roles => :ground_zero do
        deprec2.push_configs(:tsung, SYSTEM_CONFIG_FILES[:tsung])
      end

      desc "Start tsung recorder"
      task :recorder, :roles => :ground_zero do
        send(run_method, "tsung recorder")
      end

      desc "Stop tsung recorder"
      task :stop_recorder, :roles => :ground_zero do
        send(run_method, "tsung stop_recorder")
      end

      desc "Start tsung"
      task :start, :roles => :ground_zero do
        send(run_method, "tsung start")
      end

      desc "Stop tsung"
      task :stop, :roles => :ground_zero do
        send(run_method, "tsung stop")
      end

    end 
  end
end
