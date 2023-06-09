module Util
    extend self

    def self.log(thing)
        puts %(#{Time.local} -- #{thing})
    end
end