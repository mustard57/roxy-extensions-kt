#
# Put your custom functions in this class in order to keep the files under lib untainted
#
# This class has access to all of the stuff in deploy/lib/server_config.rb
#
class ServerConfig
	
	ProductionClusterName = "Production"
	DRClusterName = "DR"
	adminUserRole = "adminUserRole" # Set this to the role that admins should have
	applicationUserRole = "applicationUserRole" # set this to the role that application users should have
	
  # Run scripts specified in comma separated setup-scripts
  def execute_setup_scripts
		if @properties["ml.setup-scripts"]
			@properties["ml.setup-scripts"].split(",").each do|scriptname|
				execute_script scriptname
			end
		else
			puts "No setup scripts specified using setup-scripts build variable"
		end  
  end

  def create_application_replica_forests
	create_replica_forests @properties["ml.content-db"]
	create_replica_forests @properties["ml.modules-db"]
  end    

  def delete_application_replica_forests
	delete_replica_forests @properties["ml.content-db"]
	delete_replica_forests @properties["ml.modules-db"]
  end    
  
  def create_system_replica_forests
	# create_replica_forests "App-Services"
	create_replica_forests "Triggers"
	create_replica_forests "Last-Login"
	create_replica_forests "Meters"
	create_replica_forests "Fab"
	create_replica_forests "Extensions"	
	# create_replica_forests "Security"	
	# create_replica_forests "Schemas"	
  end

  def delete_system_replica_forests
	# delete_replica_forests "App-Services"
	# delete_replica_forests "Schemas"
	delete_replica_forests "Triggers"
	# delete_replica_forests "Security"	
  end
  
  def restart_failed_forests
	restart_forests @properties["ml.content-db"]
	restart_forests @properties["ml.modules-db"]  
	restart_forests "App-Services"
	restart_forests "Schemas"
	restart_forests "Triggers"
	restart_forests "Security"	  
  end
  
  def create_replica_forests(database_name)
	if @properties["ml.replica-forest-directory"]
		directories = @properties["ml.replica-forest-directory"].split(",")
		logger.info "Creating replication - #{directories.length} levels"
		directory = directories.each{
			|directory|
			logger.info "Creating replica forests for #{database_name} in directory #{directory}"
			arg_names = ["DATABASE_NAME","REPLICA_FOREST_DIRECTORY"]
			arg_values = [database_name,directory]
			# Run versus Security db unless we are processing the security db itself
			run_database = (database_name != "Security") ? "Security" : @properties["ml.content-db"]
			execute_script_with_variables "deploy/setup-scripts/create-replica-forests.xqy",arg_names,arg_values, run_database
			logger.info "create_replica_forests finished"
		}
	else
		logger.info "replica-forest-directory property not set - no replica forests will be created"
	end
  end    

  def delete_replica_forests(database_name)
	logger.info "Deleting replica forests for #{database_name}"
	arg_names = ["DATABASE_NAME"]
	arg_values = [database_name]
	# Run versus Security db unless we are processing the security db itself
	run_database = (database_name != "Security") ? "Security" : @properties["ml.content-db"]	
	execute_script_with_variables "deploy/setup-scripts/delete-replica-forests.xqy",arg_names,arg_values, run_database
	logger.info "delete_replica_forests finished for #{database_name}"
  end    
  
  def restart_forests(database_name)
	logger.info "Restarting forests for #{database_name}"
	arg_names = ["DATABASE_NAME"]
	arg_values = [database_name]
	# Run versus Security db unless we are processing the security db itself
	run_database = (database_name != "Security") ? "Security" : @properties["ml.content-db"]	
	execute_script_with_variables "deploy/setup-scripts/forest-restart.xqy",arg_names,arg_values, run_database
	logger.info "restart_forests finished for #{database_name}"
   end
  
  
  def couple_clusters
	get_admin_password  
	get_dr_admin_password
	
	params = {:foreign_host => @properties["ml.dr-host"], :cluster_name => ProductionClusterName, :remote_cluster_name=> DRClusterName, 
		:application_port => @properties["ml.app-port"], :foreign_host_user => @properties["ml.dr-admin-user"], :foreign_host_password => @properties["ml.dr-admin-password"]}
	url = %Q{http://#{@properties["ml.server"]}:#{@properties["ml.app-port"]}/admin/couple-clusters.xqy}
	url = url_with_parameters(url,params)
	logger.info "Linking #{@properties["ml.server"]} to #{@properties["ml.dr-host"]}"
	go url,'get',{},nil,nil,@properties["ml.user"], @properties["ml.password"]
	
	params = {:foreign_host => @properties["ml.server"], :cluster_name => DRClusterName, :remote_cluster_name=> ProductionClusterName, 
		:application_port => @properties["ml.app-port"], :foreign_host_user => @properties["ml.user"], :foreign_host_password => @properties["ml.password"]}
	url = %Q{http://#{@properties["ml.dr-host"]}:#{@properties["ml.app-port"]}/admin/couple-clusters.xqy}
	url = url_with_parameters(url,params)		
	logger.info "Linking #{@properties["ml.dr-host"]} to #{@properties["ml.server"]}"	
	go url,'get',{},nil,nil, @properties["ml.dr-admin-user"], @properties["ml.dr-admin-password"]
  end

  def decouple_clusters
	get_admin_password
	get_dr_admin_password
	
	begin
		params = {:remote_cluster_name=> DRClusterName}
		url = %Q{http://#{@properties["ml.server"]}:#{@properties["ml.app-port"]}/admin/decouple-clusters.xqy}
		url = url_with_parameters(url,params)
		logger.info "Unlinking #{@properties["ml.server"]} from #{@properties["ml.dr-host"]}"
		go url,'get',{},nil,nil,@properties["ml.user"], @properties["ml.password"]
	rescue
		logger.info "An error occurred when trying to unlink these clusters. Investigate the logs and admin screens. You may have to perform this step manually. If you are in a DR situation this may relate to host unavailability"
	end
	
	begin
		params = {:remote_cluster_name=> ProductionClusterName}
		url = %Q{http://#{@properties["ml.dr-host"]}:#{@properties["ml.app-port"]}/admin/decouple-clusters.xqy}
		url = url_with_parameters(url,params)		
		logger.info "Unlinking #{@properties["ml.dr-host"]} from #{@properties["ml.server"]}"	
		go url,'get',{},nil,nil, @properties["ml.dr-admin-user"], @properties["ml.dr-admin-password"]
	rescue
		logger.info "An error occurred when trying to unlink these clusters. Investigate the logs and admin screens. You may have to perform this step manually. If you are in a DR situation this may relate to host unavailability"
	end		
  end
  
  def replicate_database(database = @properties["ml.content-db"])
	get_admin_password  
	get_dr_admin_password
  
	params = {:remote_cluster_name=> DRClusterName, :application_port => @properties["ml.app-port"], :foreign_host_user => @properties["ml.dr-admin-user"], :foreign_host_password => @properties["ml.dr-admin-password"], :database_name => database}
	url = %Q{http://#{@properties["ml.server"]}:#{@properties["ml.app-port"]}/admin/add-database-replication.xqy}
	url = url_with_parameters(url,params)
	logger.info "Setting up replication for #{database} from #{@properties["ml.server"]} to #{@properties["ml.dr-host"]} - master side"
	go url,'get',{},nil,nil,@properties["ml.user"], @properties["ml.password"]

	params = {:remote_cluster_name=> ProductionClusterName, :application_port => @properties["ml.app-port"], :foreign_host_user => @properties["ml.user"], :foreign_host_password => @properties["ml.password"], :database_name => database}
	url = %Q{http://#{@properties["ml.dr-host"]}:#{@properties["ml.app-port"]}/admin/add-database-master.xqy}
	url = url_with_parameters(url,params)
	logger.info "Setting up replication for #{database} from #{@properties["ml.server"]} to #{@properties["ml.dr-host"]} - replica side"
	go url,'get',{},nil,nil, @properties["ml.dr-admin-user"], @properties["ml.dr-admin-password"]
  end
  
  def remove_database_replication(database = @properties["ml.content-db"])	
	get_admin_password  
	get_dr_admin_password
  
	begin
		params = {:database_name => database}
		url = %Q{http://#{@properties["ml.dr-host"]}:#{@properties["ml.app-port"]}/admin/delete-database-master.xqy}
		url = url_with_parameters(url,params)
		logger.info "Removing replication for #{database} from #{@properties["ml.server"]} to #{@properties["ml.dr-host"]} - replica side"
		go url,'get',{},nil,nil,@properties["ml.dr-admin-user"], @properties["ml.dr-admin-password"]	
	rescue
		logger.info "An error occurred when trying to remove database replication. Investigate the logs and admin screens. You may have to perform this step manually. If you are in a DR situation this may relate to host unavailability"
	end

	begin
		params = {:database_name => database}
		url = %Q{http://#{@properties["ml.server"]}:#{@properties["ml.app-port"]}/admin/delete-database-replication.xqy}
		url = url_with_parameters(url,params)
		logger.info "Removing replication for #{database} from #{@properties["ml.server"]} to #{@properties["ml.dr-host"]} - master side"
		go url,'get',{},nil,nil,@properties["ml.user"], @properties["ml.password"]
	rescue
		logger.info "An error occurred when trying to remove database replication. Investigate the logs and admin screens. You may have to perform this step manually. If you are in a DR situation this may relate to host unavailability"
	end		
  end
  
  def replicate_security_database
	replicate_database "Security"
  end
  
  def remove_security_database_replication
	remove_database_replication "Security"
  end
  
  
  def rollback_incomplete_transaction
	logger.info "Rolling back incomplete transactions"
	arg_names = ["DATABASE_NAME"]
	arg_values = [@properties["ml.content-db"]]
	run_database = "Security"
	execute_script_with_variables "src/admin/rollback-incomplete-transactions.xqy",arg_names,arg_values, run_database
	logger.info "Rollback complete for #{@properties["ml.content-db"]}"
  end    
  
  # Utility method to add parameters to url
  def url_with_parameters(url,params)	
	param_strings = []
	params.each do |key,value| 
		param_strings.push "#{key}=#{value}" 
	end
	( param_strings.length > 0 ) ? url + "?" + param_strings.join("&") : url	
  end

  # Utility method to run a specific script
  def execute_script(filename)
	execute_script_with_variables filename,[],[],@properties["ml.content-db"]
  end   
  
  # Run script with supplied variables
  # Works using string substitution
  def execute_script_with_variables(script_name,arg_names,arg_values, database_name)
	is_ok = true
	if arg_names.length != arg_values.length
		logger.info "Mismatch between argument names and values"
		is_ok = false
	end
	if File.exist?(script_name)
		script = File.read(script_name)
		arg_names.each_with_index {
			|val, index| 
			if script.include? val 
				script["#"+val+"#"] = arg_values[index]
			else
				is_ok = false
				logger.info "Argument #{val} not found in #{script_name}"
			end
		}		
		if is_ok
			logger.info "Running #{script_name}"
			execute_query script,{ :db_name => database_name }
		else
			logger.info "#{script_name} not run"		
		end
	else
		logger.info "No script with name #{script_name} found"
	end
  end

  def change_password_2(username,password)
	puts "You are changing the password for #{username}"
	if password
		puts "Password supplied - assume you know what you're doing"
    if (!password.match /^.*(?=.{8,})(?=.*[a-z])(?=.*[A-Z])(?=.*[\d]).*$/)
      raise ExitException.new("Password rules not met (minimum 8 chars, mixture of cases and at least one number)")
    end
		password_confirmation = password
	else
		password = get_password_from_command_line
	end
	arg_names = ["USER_NAME","PASSWORD"]
	arg_values = [username,password]		
	execute_script_with_variables "deploy/setup-scripts/change-password.xqy",arg_names,arg_values, @properties["ml.content-db"]
	puts "Password changed on #{@environment}"
  end
  
  def change_password
    username = ARGV.shift
	password = ARGV.shift
	change_password_2(username,password)
  end
  
  def get_password_from_command_line
	if STDIN.respond_to?(:noecho)
		print "Enter new password : "
		password=STDIN.noecho(&:gets).chomp
    if (!password.match /^.*(?=.{8,})(?=.*[a-z])(?=.*[A-Z])(?=.*[\d]).*$/)
      raise ExitException.new("Password rules not met (minimum 8 chars, mixture of cases and at least one number)")
    end
		print "\n"	  
		print "Confirm password : "
		password_confirmation=STDIN.noecho(&:gets).chomp
		print "\n"	  
		if(password == password_confirmation)
			puts "Passwords match"
		else
			raise ExitException.new("Passwords do not match. Exiting")
		end		  
	else
		raise ExitException.new("Upgrade to Ruby >= 1.9 for password prompting on the shell. Alternatively do password changes in admin console")
	end
	password
  end  
  
  def change_password_multiple_environments
	username = ARGV.shift
	puts "You are changing the password for #{username}"
	password = get_password_from_command_line
	environments = ARGV
	while env = environments.shift do
		ARGV.unshift password
		ARGV.unshift username
		ARGV.unshift "change_password"
		ARGV.unshift env
		@properties = ServerConfig.properties
		command  = ARGV.shift
		
		@s = ServerConfig.new(
          :config_file => File.expand_path(@properties["ml.config.file"], __FILE__),
          :properties => @properties,
          :logger => @logger
        ).send(command)		
	end
  end

  def add_admin_user
	add_user(adminUserRole)
  end
  
  def add_application_user
	add_user(applicationUserRole)
  end
  
  def add_user(user_role)
	username = ARGV.shift
	password = random_string(8)
	puts "You are adding user #{username}"
	arg_names = ["USER_NAME","PASSWORD","USER-ROLE"]
	arg_values = [username,password,user_role]		
	execute_script_with_variables "deploy/setup-scripts/add-user.xqy",arg_names,arg_values, @properties["ml.content-db"]
	puts "User added on #{@environment}"
	puts "Password set to #{password}"  
  end

  def random_string(length=10)
    chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789'
    password = ''
    length.times { password << chars[rand(chars.size)] }
    password
  end  

  def get_admin_password
	if @properties["ml.password"] == ""
		if STDIN.respond_to?(:noecho)
			print "Enter password for #{@properties["ml.user"]} on #{@properties["ml.server"]} : (PROD)\n"
			password=STDIN.noecho(&:gets).chomp
			@properties["ml.password"] = password
		else
			raise ExitException.new("Upgrade to Ruby >= 1.9 for password prompting on the shell. Alternatively, specify dr_admin_password in properties file")
		end
	end	
  end  

  def get_dr_admin_password
	if @properties["ml.dr-admin-password"] != ""
		@properties["ml.dr-admin-password"]	
	else
		if STDIN.respond_to?(:noecho)
			print "Enter password for #{@properties["ml.dr-admin-user"]} on #{@properties["ml.dr-host"]} : (DR)\n"
			password=STDIN.noecho(&:gets).chomp
			@properties["ml.dr-admin-password"] = password
		else
			raise ExitException.new("Upgrade to Ruby >= 1.9 for password prompting on the shell. Alternatively, specify dr_admin_password in properties file")
		end
	end	
  end  
  
end          