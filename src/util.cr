module Util
    extend self

    # Log thing
    def self.log(thing)
        puts %(#{Time.local} -- #{thing})
    end
end