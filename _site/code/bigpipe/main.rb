require 'sinatra'
require 'erb'
require "sinatra/reloader" if development?
#require "sinatra/streaming"
require 'eventmachine'

module Sinatra
  module Helpers
    class Stream
      def each(&front)
        @front = front
        callback do
          @front.call("0\r\n\r\n")
        end

        @scheduler.defer do
          begin
            @back.call(self)
          rescue Exception => e
            @scheduler.schedule { raise e }
          end
          close unless @keep_open
        end
      end

      def <<(data)
        @scheduler.schedule do
          size = data.to_s.bytesize
          @front.call([size.to_s(16), "\r\n", data.to_s, "\r\n"].join)
        end
        self
      end
    end
  end
end

set server: ['thin','webrick']
set bind: '0.0.0.0'

get '/' do
  sleep 2
  @pagelat1 = "这是第一块"
  sleep 5
  @pagelat2 = "这是第二块"
  erb(:normal)
end

get '/chunked' do
  response['Transfer-Encoding'] = 'chunked'
  stream :keep_open do |out|
    out << erb(:bigpipe)
    sleep 2
    out << '<script>Bigpipe.puts("pagelat1","这是第一块")</script>'
    sleep 5
    out << '<script>Bigpipe.puts("pagelat2","这是第二块")</script>'
    out.close
  end
end

get '/bigpipe' do
  response['Transfer-Encoding'] = 'chunked'
  stream :keep_open do |out|
    queue = []
    #当两个任务都执行完毕，关闭连接。
    callback = proc do |result|
      queue << 1
      out << result
      out.close if queue.length > 1
    end
    out << erb(:bigpipe)
    EM.epoll
    EM.run do

      EM.defer(proc{
        sleep 2
        '<script>Bigpipe.puts("pagelat1","这是第一块")</script>'
      },callback)

      EM.defer(proc {
        sleep 3
        str = erb(:list)
        '<script>Bigpipe.puts("pagelat2","'+str.gsub(/\n/,'') +'")</script>'
      },callback)
    end
  end
end
