require 'spec_helper'
require 'ostruct'

describe PoroRepository::WeakHash do

  subject do
    PoroRepository::WeakHash.new.tap do |h|
      h[:key1] = 'value1'
      h[:key2] = 'value2'
    end
  end

  describe do
    specify "accessing non-existent key returns nil" do
      subject[:non_existent_key].should be_nil
    end
  end

end
