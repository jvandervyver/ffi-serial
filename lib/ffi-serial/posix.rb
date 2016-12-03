module Serial #:nodoc:

  # Load the OS specific implementation
  begin #:nodoc:
    host_info = begin
      RbConfig::CONFIG['host_os']
    rescue Exception
      require 'rbconfig'
      RbConfig::CONFIG['host_os']
    end

    if (host_info =~ /darwin/)
      require 'ffi-serial/darwin'
    elsif (host_info =~ /linux/)
      require 'ffi-serial/linux'
    elsif (host_info =~ /bsd/)
      require 'ffi-serial/bsd'
    else
      raise LoadError.new 'The current operating system is not (yet) supported'
    end
  end

  ##
  # Serial port implementation for Posix
  module Posix #:nodoc:
    ##
    # Create a new serial port on a Posix based operating system
    def self.new(dev, baud, data_bits, stop_bits, parity) #:nodoc:
      # Parse configuration first
      termios = LIBC::Termios.new

      baud = LIBC::CONSTANTS['BAUD'].fetch(baud, nil)
      if baud.nil?
        raise ArgumentError.new "Invalid baud, supported values #{CONSTANTS['BAUD'].keys.inspect}"
      end
      LIBC.cfsetispeed(termios, baud)
      LIBC.cfsetospeed(termios, baud)

      termios.data_bits = data_bits
      termios.stop_bits = stop_bits
      termios.parity = parity

      io = File.open(dev, IO::RDWR | IO::NOCTTY | IO::NONBLOCK)
      begin
        io.sync = true
        io.fcntl(LIBC::CONSTANTS['F_SETFL'], (io.fcntl(LIBC::CONSTANTS['F_GETFL']) & (~IO::NONBLOCK)))
        io.instance_variable_set(:@__serial__dev__, dev.freeze)

        termios[:c_iflag] = (termios[:c_iflag] | LIBC::CONSTANTS['IXON'] | LIBC::CONSTANTS['IXOFF'] | LIBC::CONSTANTS['IXANY'])
        termios[:c_cflag] = (termios[:c_cflag] | LIBC::CONSTANTS['CLOCAL'] | LIBC::CONSTANTS['CREAD'] | LIBC::CONSTANTS['HUPCL'])

        LIBC.tcsetattr(io,  termios)
        io.extend(self)
      rescue Exception
        begin; io.close; rescue Exception; end
        raise
      end
      io
    end

    # It seems like VMIN and VTIME is broken :(
    # So this seems to be the only way to implement read the way it should be
    def read(length = nil, buffer = nil) #:nodoc:
      if length.nil?
        IO.select([self]) # Block

        if buffer.nil?
          return super
        else
          return super(nil, buffer)
        end
      end

      read_count = 0
      data_read = []
      while(length > read_count)
        IO.select([self]) # Block
        data_read << (partial_read = super(length))
        read_count += partial_read.length
      end

      data_read = data_read.join
      return data_read if buffer.nil?
      buffer.gsub!(buffer, data_read) # :sigh: not sure how to do this better
      buffer
    end

    def readpartial(length, buffer = nil) #:nodoc:
      IO.select([self]) # Block
      if buffer.nil?
        super(length)
      else
        super(length, buffer)
      end
    end

    def baud #:nodoc:
      LIBC::CONSTANTS['BAUD_'].fetch(LIBC.cfgetispeed(LIBC.tcgetattr(self)))
    end

    def data_bits #:nodoc:
      LIBC.tcgetattr(self).data_bits
    end

    def stop_bits #:nodoc:
      LIBC.tcgetattr(self).stop_bits
    end

    def parity #:nodoc:
      LIBC.tcgetattr(self).parity
    end

    def to_s #:nodoc:
      ['#<Serial:', @__serial__dev__, '>'].join.to_s
    end

    def inspect #:nodoc:
      self.to_s
    end

    private

    ##
    # FFI integration with C to provide access to OS specific serial port APIs
    module LIBC #:nodoc:
      require 'ffi'

      extend FFI::Library #:nodoc:
      ffi_lib FFI::Library::LIBC

      def self.tcgetattr(ruby_io) #:nodoc:
        termios = Termios.new
        return termios if (0 == c_tcgetattr(ruby_io.fileno, termios))
        raise ERRNO[FFI.errno].new
      end

      def self.tcsetattr(ruby_io, termios) #:nodoc:
        return true if (0 == c_tcsetattr(ruby_io.fileno, CONSTANTS['TCSANOW'], termios))
        raise ERRNO[FFI.errno].new
      end

      def self.cfsetispeed(termios, speed)
        return true if (0 == c_cfsetispeed(termios, speed))
        raise ERRNO[FFI.errno].new
      end

      def self.cfsetospeed(termios, speed)
        return true if (0 == c_cfsetospeed(termios, speed))
        raise ERRNO[FFI.errno].new
      end

      class Termios #:nodoc:
        def data_bits=(val) #:nodoc:
          mask = CONSTANTS['DATA_BITS'].fetch(val, nil)
          if mask.nil?
            raise ArgumentError.new "Invalid data bits, supported values #{CONSTANTS['DATA_BITS'].keys.inspect}"
          end
          self[:c_cflag] = self[:c_cflag] | mask; val
        end

        def data_bits #:nodoc:
          CONSTANTS['DATA_BITS_'].fetch(self[:c_cflag] & CONSTANTS['DATA_BITS_BITMASK'])
        end

        def stop_bits=(val) #:nodoc:
          mask = CONSTANTS['STOP_BITS'].fetch(val, nil)
          if mask.nil?
            raise ArgumentError.new "Invalid stop bits, supported values #{CONSTANTS['STOP_BITS'].keys.inspect}"
          end
          self[:c_cflag] = self[:c_cflag] | mask; val
        end

        def stop_bits #:nodoc:
          CONSTANTS['STOP_BITS_'].fetch(self[:c_cflag] & CONSTANTS['STOP_BITS_BITMASK'])
        end

        def parity=(val) #:nodoc:
          mask = CONSTANTS['PARITY'].fetch(val, nil)
          if mask.nil?
            raise ArgumentError.new "Invalid parity, supported values #{CONSTANTS['PARITY'].keys.inspect}"
          end
          if (:none == val)
            self[:c_iflag] = self[:c_iflag] | LIBC::CONSTANTS['IGNPAR']
          end
          self[:c_cflag] = self[:c_cflag] | mask; val
        end

        def parity #:nodoc:
          CONSTANTS['PARITY_'].fetch(self[:c_cflag] & CONSTANTS['PARITY_BITMASK'])
        end
      end

      CONSTANTS ||= begin #:nodoc:
        constants = self.os_specific_constants
        constants['BAUD_'] = constants['BAUD'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['DATA_BITS_'] = constants['DATA_BITS'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['STOP_BITS_'] = constants['STOP_BITS'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['PARITY_'] = constants['PARITY'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['DATA_BITS_BITMASK'] = constants['DATA_BITS'].values.max
        constants['STOP_BITS_BITMASK'] = constants['STOP_BITS'].values.max
        constants['PARITY_BITMASK'] = constants['PARITY'].values.max
        constants.freeze
      end

      ERRNO ||= Errno.constants.each_with_object({}) { |e, r| e = Errno.const_get(e); r[e::Errno] = e }.freeze #:nodoc:

      attach_function :c_tcgetattr, :tcgetattr, [:int, :buffer_in], :int #:nodoc:
      attach_function :c_tcsetattr, :tcsetattr, [:int, :int, :buffer_out], :int #:nodoc:

      attach_function :c_cfsetispeed, :cfsetispeed, [:buffer_in, :uint32], :int #:nodoc:
      attach_function :c_cfsetospeed, :cfsetospeed, [:buffer_in, :uint32], :int #:nodoc:
      attach_function :cfgetispeed, [:buffer_in], :uint32 #:nodoc:

      private_class_method :os_specific_constants, :c_tcgetattr, :c_tcsetattr, :c_cfsetispeed, :c_cfsetospeed #:nodoc:
      private_constant :ERRNO #:nodoc:
    end

    private_constant :LIBC #:nodoc:
    private_class_method :new #:nodoc:
  end
end