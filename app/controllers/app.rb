# frozen_string_literal: true

require 'roda'
require 'json'
require 'logger'

require_relative '../transactions'

module FinanceTracker
    class Api < Roda
        plugin :environments
        plugin :halt
        plugin :common_logger, $stderr

        configure do
            Transactions.setup
        end

        route do |routing|
            response['Content-Type'] = 'application/json'

            routing.root do
                response.status = 200
                { message: 'Finance Tracker API up at /api/v1' }.to_json
            end

            routing.on 'api' do
                routing.on 'v1' do
                    routing.on 'transactions' do
                        # GET /api/v1/transactions/[id]
                        routing.get String do |id|
                            response.status = 200
                            Transactions.find(id).to_json
                        rescue StandardError
                            routing.halt 404, { message: 'Transaction not found'}.to_json
                        end

                        # GET api/v1/transactions
                        routing.get do
                            response.status = 200
                            output = { transaction_ids: Transactions.all }
                            JSON.pretty_generate(output)
                        end

                        # POST api/v1/transactions
                        routing.post do
                            new_data = JSON.parse(routing.body.read)
                            new_transaction = Transactions.new(new_data)

                            if new_transaction.save
                                response.status = 201
                                { message: 'Transaction saved successfully', id: new_transaction.id }.to_json 
                            else
                                routing.halt 400, { message: 'Could not save transaction records' }.to_json
                            end
                        end
                    end
                end
            end
        end
    end
end
