module Serial #:nodoc:
  module Windows #:nodoc:
    def self.new(com_port, baud, data_bits, stop_bits, parity) #:nodoc:
      # Either specify as 'COM1' or a number. eg 1 for 'COM1'
      begin
        as_int = Integer(com_port)
        com_port = '\\\\.\\COM' + as_int.to_s
      rescue StandardError
        com_port = '\\\\.\\' + com_port.to_s.strip.chomp.upcase
      end

      dcb = Kernel32::DCB.new

      dcb.baud = baud
      dcb.data_bits = data_bits
      dcb.stop_bits = stop_bits
      dcb.parity = parity

      io = File.open(com_port, IO::RDWR|IO::BINARY)
      begin
        io.instance_variable_set(:@__serial__port__, com_port[4..-1].to_s.freeze)

        io.extend(self)
        io.sync = true

        # Sane defaults
        dcb[:Flags] = dcb[:Flags] | (Kernel32::CONSTANTS['FLAGS'].fetch('fDtrControl').fetch(:enable))
        dcb[:XonChar] = 17
        dcb[:XoffChar] = 19

        Kernel32.SetCommState(io, dcb)
        Kernel32.ClearCommError(io)
        Kernel32.set_io_block(io)
      rescue Exception
        begin; io.close; rescue Exception; end
        raise
      end
      io
    end

    def baud #:nodoc:
      Kernel32.GetCommState(self).baud
    end

    def data_bits #:nodoc:
      Kernel32.GetCommState(self).data_bits
    end

    def stop_bits #:nodoc:
      Kernel32.GetCommState(self).stop_bits
    end

    def parity #:nodoc:
      Kernel32.GetCommState(self).parity
    end

    def read_nonblock(maxlen, outbuf = nil, options = nil) #:nodoc:
      Kernel32.set_io_nonblock(self)
      result = begin
        outbuf.nil? ? read(maxlen) : read(maxlen, outbuf)
      ensure
        Kernel32.set_io_block(self)
      end

      if result.nil? || (0 == result.length)
        if ((!options.nil?) && (false == options[:exception]))
          return :wait_readable
        end
        raise Errno::EWOULDBLOCK.new
      end
      result
    end

    def readpartial(maxlen, outbuf = nil) #:nodoc:
      ch = self.read(1)
      if (ch.nil? || (0 == ch.length))
        return ch
      end
      self.ungetc(ch)
      Kernel32.set_io_nonblock(self)
      outbuf.nil? ? read(maxlen) : read(maxlen, outbuf)
    ensure
      Kernel32.set_io_block(self)
    end

    def readbyte #:nodoc:
      Kernel32.set_io_nonblock(self); super
    ensure
      Kernel32.set_io_block(self)
    end

    def getc #:nodoc:
      Kernel32.set_io_nonblock(self); super
    ensure
      Kernel32.set_io_block(self)
    end

    def readchar #:nodoc:
      Kernel32.set_io_nonblock(self); super
    ensure
      Kernel32.set_io_block(self)
    end

    def to_s #:nodoc:
      ['#<Serial:', @__serial__port__, '>'].join.to_s
    end

    def inspect #:nodoc:
      self.to_s
    end

    ##
    # FFI integration with Kernel32.dll to provide access to OS specific serial port APIs
    module Kernel32 #:nodoc:
      require 'ffi'

      extend FFI::Library #:nodoc:
      ffi_lib 'kernel32'
      ffi_convention :stdcall

      def self.GetCommState(ruby_io) #:nodoc:
        dcb = DCB.new
        dcb[:DCBlength] = dcb.size
        return dcb unless (0 == c_GetCommState(LIBC._get_osfhandle(ruby_io), dcb))
        raise ERRNO[FFI.errno].new
      end

      def self.SetCommState(ruby_io, dcb) #:nodoc:
        dcb[:DCBlength] = dcb.size
        dcb[:Flags] = dcb[:Flags] | 1 # fBinary must be true
        return true unless (0 == c_SetCommState(LIBC._get_osfhandle(ruby_io), dcb))
        raise ERRNO[FFI.errno].new
      end

      def self.GetCommTimeouts(ruby_io) #:nodoc:
        commtimeouts = COMMTIMEOUTS.new
        return commtimeouts unless (0 == c_GetCommTimeouts(LIBC._get_osfhandle(fd), commtimeouts))
        raise ERRNO[FFI.errno].new
      end

      def self.SetCommTimeouts(ruby_io, commtimeouts) #:nodoc:
        return true unless (0 == c_SetCommTimeouts(LIBC._get_osfhandle(ruby_io), commtimeouts))
        raise ERRNO[FFI.errno].new
      end

      def self.ClearCommError(ruby_io) #:nodoc:
        return true unless (0 == c_ClearCommError(LIBC._get_osfhandle(ruby_io), 0, 0))
        raise ERRNO[FFI.errno].new
      end

      def self.set_io_block(ruby_io) #:nodoc:
        self.SetCommTimeouts(ruby_io, (@@read_block_io ||= begin
          timeouts = COMMTIMEOUTS.new
          timeouts[:ReadIntervalTimeout] = CONSTANTS['MAXDWORD']
          timeouts[:ReadTotalTimeoutMultiplier] = CONSTANTS['MAXDWORD']
          timeouts[:ReadTotalTimeoutConstant] = CONSTANTS['MAXDWORD'] - 1
          timeouts[:WriteTotalTimeoutMultiplier] = 0
          timeouts[:WriteTotalTimeoutConstant] = CONSTANTS['MAXDWORD'] - 1
          timeouts
        end))
      end

      def self.set_io_nonblock(ruby_io) #:nodoc:
        self.SetCommTimeouts(ruby_io, (@@read_nonblock_io ||= begin
          timeouts = COMMTIMEOUTS.new
          timeouts[:ReadIntervalTimeout] = CONSTANTS['MAXDWORD']
          timeouts[:ReadTotalTimeoutMultiplier] = 0
          timeouts[:ReadTotalTimeoutConstant] = 0
          timeouts[:WriteTotalTimeoutMultiplier] = 1
          timeouts[:WriteTotalTimeoutConstant] = 1
          timeouts
        end))
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

        def baud=(val) #:nodoc:
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

        def baud #:nodoc:
          self[:BaudRate]
        end

        def data_bits=(val) #:nodoc:
          parsed = CONSTANTS['DATA_BITS'].fetch(val, nil)
          if parsed.nil?
            raise ArgumentError.new "Invalid data bits, supported values #{CONSTANTS['DATA_BITS'].keys.inspect}"
          end
          self[:ByteSize] = parsed; val
        end

        def data_bits #:nodoc:
          CONSTANTS['DATA_BITS_'].fetch(self[:ByteSize])
        end

        def stop_bits=(val) #:nodoc:
          parsed = CONSTANTS['STOP_BITS'].fetch(val, nil)
          if parsed.nil?
            raise ArgumentError.new "Invalid data bits, supported values #{CONSTANTS['STOP_BITS'].keys.inspect}"
          end
          self[:StopBits] = parsed; val
        end

        def stop_bits #:nodoc:
          CONSTANTS['STOP_BITS_'].fetch(self[:StopBits])
        end

        def parity=(val) #:nodoc:
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

        def parity #:nodoc:
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

      CONSTANTS ||= begin #:nodoc:
        constants = {
          'MAXDWORD' => 4294967295,
          'DATA_BITS' => { 5 => 5, 6 => 6, 7 => 7, 8 => 8 }.freeze,    
          'STOP_BITS' => { 1 => 0, 1.5 => 1, 2 => 2 }.freeze,
          'PARITY' => { none: 0, odd: 1, even: 2, mark: 3, space: 4 }.freeze,
          'FLAGS' => {
            'fParity' => 2, 'fOutxCtsFlow' => 4, 'fOutxDsrFlow' => 8,
            'fDtrControl' => { disable: 0, enable: 16, handshake: 32 }.freeze,
            'fDsrSensitivity' => 64, 'fTXContinueOnXoff' => 128, 'fOutX' => 256,
            'fInX' => 512, 'fErrorChar' => 1024, 'fNull' => 2048,
            'fRtsControl' => { disable: 0, enable: 4096, handshake: 8192,  toggle: 12288 }.freeze,
            'fAbortOnError' => 16384
          }.freeze,
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

      module LIBC #:nodoc:
        extend FFI::Library #:nodoc:
        ffi_lib FFI::Library::LIBC

        def self._get_osfhandle(ruby_io) #:nodoc:
          handle = c__get_osfhandle(ruby_io.fileno)
          return handle unless (-1 == handle)
          raise ERRNO[FFI.errno].new
        end

        attach_function :c__get_osfhandle, :_get_osfhandle, [:int], :long #:nodoc:
        private_class_method :c__get_osfhandle #:nodoc:
      end

      ERRNO ||= Errno.constants.each_with_object({}) { |e, r| e = Errno.const_get(e); r[e::Errno] = e }.freeze #:nodoc:

      attach_function :c_GetCommState, :GetCommState, [:long, :buffer_out], :int32 #:nodoc:
      attach_function :c_SetCommState, :SetCommState, [:long, :buffer_in], :int32 #:nodoc:
      attach_function :c_GetCommTimeouts, :GetCommTimeouts, [:long, :buffer_out], :int32 #:nodoc:
      attach_function :c_SetCommTimeouts, :SetCommTimeouts, [:long, :buffer_in], :int32 #:nodoc:
      attach_function :c_ClearCommError, :ClearCommError, [:long, :int, :int], :int32 #:nodoc:
      private_class_method :c_GetCommState, :c_SetCommState, :c_GetCommTimeouts, :c_SetCommTimeouts, :c_ClearCommError #:nodoc:
      private_constant :LIBC, :ERRNO #:nodoc:
    end

    private_constant :Kernel32 #:nodoc:
  end
end