# recursive compact methods
class Array
  # with an array of hashes, recurse into each, compact 
  # the elements and return a new compacted array
  def compact_recursive
    inject([]) do |new_array, (v)|
      if !v.nil?
        if v.class == Hash || v.class == Array
          compacted = v.compact_recursive
          if compacted.size > 0
            new_array << compacted
          end
        # remove redacted values
        elsif v.class == String
          if v.match(/^\*+$/)
            new_array
          else
            new_array << v
          end
        else
          new_array << v
        end
      end
      new_array
    end
  end
end
class Hash
  # recurse into a hash and remove nil values
  def compact_recursive
    inject({}) do |new_hash, (k,v)|
      if !v.nil? 
        if v.class == Hash || v.class == Array
          compacted = v.compact_recursive
          if compacted.size > 0
            new_hash[k] = compacted
          end
        # remove redacted values
        elsif v.class == String
          if v.match(/^\*+$/)
            new_hash
          else
            new_hash[k] = v
          end
        else
          new_hash[k] = v
        end
      end
      new_hash
    end
  end
end
