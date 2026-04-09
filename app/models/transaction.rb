require 'securerandom'
require 'json'

module FinanceTracker
    STORE_DIR = 'app/db/store'
    class Transaction
        attr_reader :id, :amount, :date, :title

        def initialize(new_info)
            @id = new_info['id'] || new_id
            @amount = new_info['amount']
            @date = new_info['date']
            @title = new_info['title']
        end

        def new_id
            SecureRandom.uuid
        end

        def to_json
            JSON.generate({
                'id' => @id,
                'amount' => @amount,
                'title' => @title,
                'date' => @date
            })
        end

        def save
            File.write("#{STORE_DIR}/#{@id}.txt", to_json)
        end

        def self.find(id)
           file_data = File.read("#{STORE_DIR}/#{id}.txt") 
           Transaction.new(JSON.parse(file_data))
        end

        def self.all
            Dir.glob("#{STORE_DIR}/*.txt").map do |file|
                File.basename(file,'.txt')
            end
        end


    end
end

