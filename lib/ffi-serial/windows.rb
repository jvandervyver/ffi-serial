module FFISerial #:nodoc:
  module Windows #:nodoc:
    def self.new(com_port, baud, data_bits, stop_bits, parity) #:nodoc:
      # Either specify as 'COM1' or a number. eg 1 for 'COM1'
      begin
        as_int = Integer(com_port)
        com_port = '\\\\.\\COM' + as_int.to_s
      rescue StandardError
        com_port = '\\\\.\\' + com_port
      end

      config = Kernel32::DCB.new
      config[:Flags] = 0

      config.baud = baud
      config.data_bits = data_bits
      config.stop_bits = stop_bits
      config.parity = parity

      io = File.open(com_port, IO::RDWR|IO::BINARY)
      begin
        io.instance_variable_set(:@__serial__port__, com_port[4..-1].to_s.freeze)

        io.extend(self)
        io.sync = true

        # Sane defaults
        config[:Flags] = config[:Flags] | (Kernel32::CONSTANTS['FLAGS'].fetch('fDtrControl').fetch(:enable))
        config[:Flags] = config[:Flags] | (Kernel32::CONSTANTS['FLAGS'].fetch('fOutX'))
        config[:Flags] = config[:Flags] | (Kernel32::CONSTANTS['FLAGS'].fetch('fInX'))

        Kernel32.SetCommState(io, config)
      rescue Exception
        begin; io.close; rescue Exception; end
        raise
      end
      io
    end

    ##
    # Query the current serial port baud rate
    def baud #:nodoc:
      Kernel32.GetCommState(self).baud
    end

    ##
    # Query the current serial port data bits
    def data_bits #:nodoc:
      Kernel32.GetCommState(self).data_bits
    end

    ##
    # Query the current serial port stop bits
    def stop_bits #:nodoc:
      Kernel32.GetCommState(self).stop_bits
    end

    ##
    # Query the current serial port parity configuration
    def parity #:nodoc:
      Kernel32.GetCommState(self).parity
    end

    def to_s #:nodoc:
      ['#<Serial:', @__serial__port__, '>'].join.to_s
    end

    def inspect #:nodoc:
      self.to_s
    end

    module Kernel32
      require 'ffi'

      extend FFI::Library #:nodoc:
      ffi_lib 'kernel32'
      ffi_convention :stdcall

      def self.GetCommState(ruby_io)
        dcb = DCB.new
        dcb[:DCBlength] = dcb.size
        if (0 != c_GetCommState(LIBC._get_osfhandle(ruby_io), dcb))
          raise ERRNO[FFI.errno].new
        end
        dcb
      end

      def self.SetCommState(ruby_io, dcb)
        dcb[:DCBlength] = dcb.size
        if (0 != c_SetCommState(LIBC._get_osfhandle(ruby_io), dcb))
          raise ERRNO[FFI.errno].new
        end
      end

      def self.GetCommTimeouts(ruby_io)
        commtimeouts = COMMTIMEOUTS.new
        if (0 != c_GetCommTimeouts(LIBC._get_osfhandle(fd), commtimeouts))
          raise ERRNO[FFI.errno].new
        end
        commtimeouts
      end

      def self.SetCommTimeouts(ruby_io, commtimeouts)
        if (0 != c_SetCommTimeouts(LIBC._get_osfhandle(ruby_io), commtimeouts))
          raise ERRNO[FFI.errno].new
        end
      end

      class DCB < FFI::Struct #:nodoc:
        layout :DCBlength, :uint32,
               :BaudRate, :uint32,
               :Flags, :uint32,
               :wReserved, :uint16,
               :XonLim, :uint16,
               :XoffLim, :uint16,
               :ByteSize, :uint8,
               :Parity, :uint8,
               :StopBits, :uint8,
               :XonChar, :int8,
               :XoffChar, :int8,
               :ErrorChar, :int8,
               :EofChar, :int8,
               :EvtChar, :int8,
               :wReserved1, :uint16

        def baud=(val)
          new_val = begin
            Integer(val)
          rescue StandardError
            -1
          end
          if (0 >= new_val)
            raise ArgumentError.new "Invalid baud, specify a positive Integer"
          end
          self[:BaudRate] = new_val; val
        end

        def baud
          self[:BaudRate]
        end

        def data_bits=(val)
          parsed = CONSTANTS['DATA_BITS'].fetch(val, nil)
          if parsed.nil?
            raise ArgumentError.new "Invalid data bits, supported values #{CONSTANTS['DATA_BITS'].keys.inspect}"
          end
          self[:ByteSize] = parsed; val
        end

        def data_bits(val)
          CONSTANTS['DATA_BITS_'].fetch(self[:ByteSize])
        end

        def stop_bits=(val)
          parsed = CONSTANTS['STOP_BITS'].fetch(val, nil)
          if parsed.nil?
            raise ArgumentError.new "Invalid data bits, supported values #{CONSTANTS['STOP_BITS'].keys.inspect}"
          end
          self[:StopBits] = parsed; val
        end

        def stop_bits(val)
          CONSTANTS['STOP_BITS_'].fetch(self[:StopBits])
        end

        def parity=(val)
          parsed = CONSTANTS['PARITY'].fetch(val, nil)
          if parsed.nil?
            raise ArgumentError.new "Invalid parity, supported values #{CONSTANTS['PARITY'].keys.inspect}"
          end
          if (:none == val)
            self[:Flags] = self[:Flags] & (~CONSTANTS['FLAGS'].fetch('fParity'))
          else
            self[:Flags] = self[:Flags] | CONSTANTS['FLAGS'].fetch('fParity')
          end
          self[:Parity] = parsed; val
        end

        def parity
          CONSTANTS['PARITY_'].fetch(self[:Parity])
        end
      end

      class COMMTIMEOUTS < FFI::Struct #:nodoc:
        layout :ReadIntervalTimeout, :uint32,
               :ReadTotalTimeoutMultiplier, :uint32,
               :ReadTotalTimeoutConstant, :uint32,
               :WriteTotalTimeoutMultiplier, :uint32,
               :WriteTotalTimeoutConstant, :uint32
      end

      CONSTANTS ||= begin
        constants = {
          'DATA_BITS' => { 5 => 5, 6 => 6, 7 => 7, 8 => 8 }.freeze,    
          'STOP_BITS' => { 1 => 0, 1.5 => 1, 2 => 2 }.freeze,
          'PARITY' => { none: 0, odd: 1, even: 2, mark: 3, space: 4 }.freeze,
          'FLAGS' => {
            'fBinary' => 1, 'fParity' => 2, 'fOutxCtsFlow' => 4, 'fOutxDsrFlow' => 8,
            'fDtrControl' => { disable: 0, enable: 16, handshake: 32 }.freeze,
            'fDsrSensitivity' => 64, 'fTXContinueOnXoff' => 128, 'fOutX' => 256,
            'fInX' => 512, 'fErrorChar' => 1024, 'fNull' => 2048,
            'fRtsControl' => { disable: 0, enable: 4096, handshake: 8192,  toggle: 12288 }.freeze,
            'fAbortOnError' => 16384
          }.freeze
        }

        constants['DATA_BITS_'] = constants['DATA_BITS'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['STOP_BITS_'] = constants['STOP_BITS'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['PARITY_'] = constants['PARITY'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['FLAGS_'] = {}
        constants['FLAGS_']['fDtrControl'] = constants['FLAGS']['fDtrControl'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['FLAGS_']['fRtsControl'] = constants['FLAGS']['fRtsControl'].each_with_object({}) { |(k,v),r| r[v] = k }.freeze
        constants['FLAGS_'].freeze

        constants.freeze
      end

      module LIBC
        extend FFI::Library #:nodoc:
        ffi_lib FFI::Library::LIBC

        def self._get_osfhandle(ruby_io)
          c__get_osfhandle(ruby_io.fileno)
        end

        attach_function :c__get_osfhandle, :_get_osfhandle, [:int], :long #:nodoc:
        private_class_method :c__get_osfhandle #:nodoc:
      end

      ERRNO ||= Errno.constants.each_with_object({}) { |e, r| e = Errno.const_get(e); r[e::Errno] = e }.freeze #:nodoc:

      attach_function :c_GetCommState, :GetCommState, [:long, :buffer_out], :bool #:nodoc:
      attach_function :c_SetCommState, :SetCommState, [:long, :buffer_in], :bool #:nodoc:
      attach_function :c_GetCommTimeouts, :GetCommTimeouts, [:long, :buffer_out], :bool #:nodoc:
      attach_function :c_SetCommTimeouts, :SetCommTimeouts, [:long, :buffer_in], :bool #:nodoc:
      private_class_method :c_GetCommState, :c_SetCommState, :c_GetCommTimeouts, :c_SetCommTimeouts #:nodoc:
      private_constant :LIBC, :ERRNO #:nodoc:
    end

    private_constant :Kernel32
  end
end