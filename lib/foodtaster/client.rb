require 'drb'

module Foodtaster
  class Client
    def self.connect(drb_port)
      retry_count = 0
      begin
        sleep 0.2
        client = Foodtaster::Client.new(drb_port)
      rescue DRb::DRbConnError => e
        Foodtaster.logger.debug "DRb connection failed: #{e.message}"
        retry_count += 1
        retry if retry_count < 20
      end

      if client.nil?
        server_output = File.read("/tmp/vagrant-foodtaster-server-output.txt")

        Foodtaster.logger.fatal "Cannot start or connect to Foodtaster DRb server."
        Foodtaster.logger.fatal "Server output:\n#{server_output}\n"

        exit 1
      else
        Foodtaster.logger.debug "DRb connection established"
      end

      client
    end

    [:vm_defined?, :prepare_vm, :rollback_vm,
     :run_chef_on_vm, :execute_command_on_vm,
     :shutdown_vm].each do |method_name|
       define_method method_name do |*args|
         begin
           @v.send(method_name, *args)
         rescue DRb::DRbUnknownError => e
           puts '='*30
           puts 'Folowing error was raised on server: '
           p e.unknown.buf
           puts '='*30
           raise e
         end
       end
     end

     private

     def initialize(drb_port)
       # start local service to be able to redirect stdout & stderr
       # to client
       DRb.start_service("druby://localhost:0")
       @v = DRbObject.new_with_uri("druby://localhost:#{drb_port}")

       init
     end


     def init
       $stdout.extend DRbUndumped
       $stderr.extend DRbUndumped

       @v.redirect_stdstreams($stdout, $stderr)
     end
  end
end
