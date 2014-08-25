require 'benchmark'
require 'rubygems'
require 'sqlite3'
require 'active_record'


ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'test.db'
)


ActiveRecord::Schema.define do

  create_table :albums do |table|

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

a = A.new
b = b.new

p A.ancestors

Benchmark.bm do |x|
  x.report('call method:') { 10000.times { a.test } }
  x.report('call method_missing:'){ 10000.times { b.test }  }
end