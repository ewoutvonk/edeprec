# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do 
    namespace :syslog_ng do
      
      set :syslog_use_default_dynamic_settings, true
      set :syslog_ng_server, nil
      set :syslog_ng_server_port, 5140
      set :syslog_ng_is_server, false # set this option to true if the server(s) mentioned in your recipe are syslog servers
      set :syslog_ng_server_max_connections, 10
      
      set :syslog_ng_options, {
        :chain_hostnames => 0,
        :time_reopen => 10,
        :time_reap => 360,
        #:sync => 0,
        :log_fifo_size => 2048,
        :create_dirs => :yes,
        #:owner => :root, 
        :group => :adm,
        :perm => :"0640",
        #:dir_owner => :root,
        #:dir_group => :root,
        :dir_perm => :"0755",
        :use_dns => :no,
        #:log_msg_size => 2048,
      	:stats_freq => 0,
      	:bad_hostname => :"^gconfd$",
      }
      set :syslog_ng_logs, {
        :s_all => {
          :df_auth => :f_auth,
          :df_syslog => :f_syslog,
          :df_cron => :f_cron,
          :df_daemon => :f_daemon,
          :df_kern => :f_kern,
          :df_lpr => :f_lpr,
          :df_mail => :f_mail,
          :df_user => :f_user,
          :df_uucp => :f_uucp,
          :df_facility_dot_info => [ :f_mail, :f_at_least_info ],
          :df_facility_dot_warn => [ :f_mail, :f_at_least_warn ],
          :df_facility_dot_err => [ :f_mail, :f_at_least_err ],
          :df_news_dot_crit => [ :f_news, :f_at_least_crit ],
          :df_news_dot_err => [ :f_news, :f_at_least_err ],
          :df_news_dot_notice => [ :f_news, :f_at_least_notice ],
          :df_debug => :f_debug,
          :df_messages => :f_messages,
          :du_all => :f_emerg,
          :dp_xconsole => :f_xconsole
        }
      }
      set :syslog_ng_sources, {
        :s_all => [
          "internal()",
          "unix-stream(\"/dev/log\")",
          "file(\"/proc/kmsg\" log_prefix(\"kernel: \"))"
        ]
      }
      set :syslog_ng_filters, {
        :f_auth => "facility(auth, authpriv)",
        :f_syslog => "not facility(auth, authpriv)",
        :f_cron => "facility(cron)",
        :f_daemon => "facility(daemon)",
        :f_kern => "facility(kern)",
        :f_lpr => "facility(lpr)",
        :f_mail => "facility(mail)",
        :f_news => "facility(news)",
        :f_user => "facility(user)",
        :f_local => "facility(local0,local1,local2,local3,local4,local5,local6,local7)",
        :f_local0 => "facility(local0)",
        :f_local1 => "facility(local1)",
        :f_local2 => "facility(local2)",
        :f_local3 => "facility(local3)",
        :f_local4 => "facility(local4)",
        :f_local5 => "facility(local5)",
        :f_local6 => "facility(local6)",
        :f_local7 => "facility(local7)",
        :f_uucp => "facility(uucp)",
        :f_at_least_info => "level(info..emerg)",
        :f_at_least_notice => "level(notice..emerg)",
        :f_at_least_warn => "level(warn..emerg)",
        :f_at_least_err => "level(err..emerg)",
        :f_at_least_crit => "level(crit..emerg)",
        :f_debug => "level(debug) and not facility(auth, authpriv, news, mail)",
        :f_messages => "level(info,notice,warn) and not facility(auth,authpriv,cron,daemon,mail,news)",
        :f_emerg => "level(emerg)",
        :f_xconsole => "facility(daemon,mail) or level(debug,info,notice,warn) or (facility(news) and level(crit,err,notice))",
        :f_daemons => "program(\"(rails-|apache-|.*mysqld|Keepalived).*\")"
      }
      set :syslog_ng_destinations, {
        :df_auth => "file(\"/var/log/auth.log\")",
        :df_syslog => "file(\"/var/log/syslog\")",
        :df_cron => "file(\"/var/log/cron.log\")",
        :df_daemon => "file(\"/var/log/daemon.log\")",
        :df_kern => "file(\"/var/log/kern.log\")",
        :df_lpr => "file(\"/var/log/lpr.log\")",
        :df_mail => "file(\"/var/log/mail.log\")",
        :df_user => "file(\"/var/log/user.log\")",
        :df_local => "file(\"/var/log/daemons/local/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local0 => "file(\"/var/log/daemons/local0/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local1 => "file(\"/var/log/daemons/local1/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local2 => "file(\"/var/log/daemons/local2/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local3 => "file(\"/var/log/daemons/local3/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local4 => "file(\"/var/log/daemons/local4/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local5 => "file(\"/var/log/daemons/local5/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local6 => "file(\"/var/log/daemons/local6/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_local7 => "file(\"/var/log/daemons/local7/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")",
        :df_uucp => "file(\"/var/log/uucp.log\")",
        :df_facility_dot_info => "file(\"/var/log/$FACILITY.info\")",
        :df_facility_dot_notice => "file(\"/var/log/$FACILITY.notice\")",
        :df_facility_dot_warn => "file(\"/var/log/$FACILITY.warn\")",
        :df_facility_dot_err => "file(\"/var/log/$FACILITY.err\")",
        :df_facility_dot_crit => "file(\"/var/log/$FACILITY.crit\")",
        :df_news_dot_notice => "file(\"/var/log/news/news.notice\" owner(\"news\"))",
        :df_news_dot_err => "file(\"/var/log/news/news.err\" owner(\"news\"))",
        :df_news_dot_crit => "file(\"/var/log/news/news.crit\" owner(\"news\"))",
        :df_debug => "file(\"/var/log/debug\")",
        :df_messages => "file(\"/var/log/messages\")",
        :dp_xconsole => "pipe(\"/dev/xconsole\")",
        :du_all => "usertty(\"*\")",
        :df_kernel => "file(\"/var/log/daemons/kernel-$HOST/$YEAR$MONTH/$DAY/kernel-$HOST-$YEAR$MONTH$DAY\")",
        :df_daemons => "file(\"/var/log/daemons/$PROGRAM/$YEAR$MONTH/$DAY/$PROGRAM-$YEAR$MONTH$DAY\")"
      }
      
      desc "Install syslog-ng"
      task :install, :roles => :syslog do
        install_deps
      end

      # install dependencies for syslog-ng
      task :install_deps, :roles => :syslog do
        apt.install( {:base => %w(syslog-ng)}, :stable )
      end
      
      SYSTEM_CONFIG_FILES[:syslog_ng] =  [
        
       { :template => 'syslog-ng.conf.erb',
         :path => '/etc/syslog-ng/syslog-ng.conf',
         :mode => 0644,
         :owner => 'root:root'}
         
      ]

      SYSTEM_CONFIG_FILES[:syslog] =  [
        
       { :template => 'syslogger',
         :path => '/usr/local/bin/syslogger',
         :mode => 0755,
         :owner => 'root:root'}
         
      ]
                      
      desc "Generate Syslog-ng configs"
      task :config_gen do
        SYSTEM_CONFIG_FILES[:syslog_ng].each do |file|
         deprec2.render_template(:syslog_ng, file)
        end
        SYSTEM_CONFIG_FILES[:syslog].each do |file|
         deprec2.render_template(:syslog, file)
        end
      end

      desc "Push Syslog-ng config files to server"
      task :config, :roles => :syslog do
        deprec2.push_configs(:syslog_ng, SYSTEM_CONFIG_FILES[:syslog_ng])
        deprec2.push_configs(:syslog, SYSTEM_CONFIG_FILES[:syslog])
      end

      desc "Start Syslog-ng"
      task :start, :roles => :syslog do
        run "#{sudo} /etc/init.d/syslog-ng start"
      end
      
      desc "Stop Syslog-ng"
      task :stop, :roles => :syslog do
        run "#{sudo} /etc/init.d/syslog-ng stop"
      end
      
      desc "Restart Syslog-ng"
      task :restart, :roles => :syslog do
        run "#{sudo} /etc/init.d/syslog-ng restart"
      end

    end 
    
  end
end
