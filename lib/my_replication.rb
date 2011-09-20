module ActiveRecord
  class Base
    class << self
      alias_method :old_find, :find

      def find(*args)
        options = args.extract_options!

        if options[:replication] && options[:replication] == true
          options.delete(:replication)
          args.push(options)
          connection.replicate {
            old_find(*args)
          }
        else
          old_find(*args)
        end
      end

      def replication
        connection.replicate {
          yield
        }
      end
    end
  end

  module ConnectionAdapters
    class MysqlAdapter
      def replicate(replica = nil)
        old = @connection
        @connection = select_replica(replica)
        yield
      ensure
        @connection = old
      end

      def select_replica replica
        if replica
          
        else
          return @replicas[rand(@replicas.size)]
        end
        
      end

      def init_replicas
        if @config[:replicas]
          @replicas = (@config[:replicas]).map{Mysql.init}
        else
          raise "No replicas specified in database.yml"
        end
      end

      private
      def connect
        # Nghi: initiate replicas and connect to them          
        init_replicas unless @replicas
        replica_with_configs = @replicas.zip(@config[:replicas])
        replica_with_configs.each do |replica_and_configs|
          replica, configs = replica_and_configs
          configs = configs.symbolize_keys
          host     = configs[:host]
          port     = configs[:port]
          socket   = configs[:socket]
          username = configs[:username] ? configs[:username].to_s : 'root'
          password = configs[:password].to_s
          database = configs[:database]
          replica.real_connect(host, username, password, database, port, socket)
          
          old = @connection
          @connection = replica
          configure_connection
          @connection = old
        end

        # Nghi: connect to master db
        @connection.real_connect(*@connection_options)
        # reconnect must be set after real_connect is called, because real_connect sets it to false internally
        @connection.reconnect = !!@config[:reconnect] if @connection.respond_to?(:reconnect=)
        configure_connection
      end
    end
  end
end
