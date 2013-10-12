require 'weakref'

# http://endofline.wordpress.com/2011/01/09/getting-to-know-the-ruby-standard-library-weakref/
class PoroRepository::WeakHash < Hash

  class AmbivalentRef < WeakRef
    def __getobj__
      super rescue nil
    end

    alias actual __getobj__
  end

  def []= key, object
    super(key, AmbivalentRef.new(object))
  end

  def [] key
    ref = super(key)
    self.delete(key) if ref && !ref.weakref_alive?
    ref
  end

end
