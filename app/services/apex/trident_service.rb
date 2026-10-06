# frozen_string_literal: true

module Apex
  class TridentService < ApexClient

    def self.trigger_alk_test!
      new.trigger_alk_test!
    end

    def trigger_alk_test!
      put base_path, '{"did":"10_4","gid":"","name":"Alk_10_4","type":"selector","ID":43,"status":["ON","","OK",""]}'
    end

  end
end
