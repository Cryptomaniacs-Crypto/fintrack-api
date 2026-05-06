# frozen_string_literal: true

require_relative 'app'

module FinanceTracker
  # Category routes
  class Api < Roda
    route('categories') do |routing|
      @category_route = "#{@api_root}/categories"

      # GET api/v1/categories/[category_id]
      routing.get String do |category_id|
        category = Category.first(id: category_id)
        category ? category.to_json : raise('Category not found')
      rescue StandardError => e
        routing.halt 404, { message: e.message }.to_json
      end

      # GET api/v1/categories
      routing.get do
        { data: Category.all }.to_json
      rescue StandardError
        routing.halt 404, { message: 'Could not find categories' }.to_json
      end

      # POST api/v1/categories
      routing.post do
        new_data = JSON.parse(routing.body.read)
        new_category = Category.new(new_data)
        raise('Could not save category') unless new_category.save_changes

        response.status = 201
        response['Location'] = "#{@category_route}/#{new_category.id}"
        { message: 'Category saved', data: new_category }.to_json
      rescue Sequel::MassAssignmentRestriction
        Api.logger.warn "MASS-ASSIGNMENT: #{new_data.keys}"
        routing.halt 400, { message: 'Illegal Attributes' }.to_json
      rescue StandardError => e
        Api.logger.error "UNKNOWN ERROR: #{e.message}"
        routing.halt 500, { message: 'Unknown server error' }.to_json
      end
    end
  end
end
