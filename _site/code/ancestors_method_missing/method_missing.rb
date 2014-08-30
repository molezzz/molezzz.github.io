require 'benchmark'
require 'rubygems'
require 'sqlite3'
require 'active_record'


ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)


#ActiveRecord::Schema.define do
ActiveRecord::Migration.class_eval do
  create_table :as do |table|

    table.column :title, :string
    table.column :performer, :string

  end

  create_table :bs do |table|

    table.column :title, :string
    table.column :performer, :string

  end

  create_table :cs do |table|

    table.column :title, :string
    table.column :performer, :string

  end
end


class A < ActiveRecord::Base

  def test
    true
  end

end

class B < ActiveRecord::Base

  def method_missing(method)
    true
  end

end

class C < ActiveRecord::Base

  def method_missing(method, *args)

    self.class.send(:define_method, method) do
      true
    end

    # self.class.class_eval <<-RUBY
    #   def #{method}(*args)
    #     true
    #   end
    # RUBY

    send(method, *args)

  end

end

a = A.new
b = B.new
c = C.new

#p A.ancestors

Benchmark.bmbm do |x|
  x.report('call method:') { 1000000.times { a.test } }
  x.report('call method_missing:'){ 1000000.times { b.test }  }
  x.report('call dynamic method:'){ 1000000.times { c.test }  }
end