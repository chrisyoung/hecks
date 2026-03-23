require "sinatra"
require "sinatra/json"
require_relative "config/hecks"

class App < Sinatra::Base
  helpers Sinatra::JSON

  before do
    content_type :json
    headers "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, PATCH, DELETE, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type"
  end

  options "*" do
    200
  end

  get '/pizzas/by_description' do
    json Pizza.by_description(params[:desc]).map { |r| serialize(r) }
  end

  get '/pizzas' do
    json Pizza.all.map { |r| serialize(r) }
  end

  get '/pizzas/:id' do
    result = Pizza.find(params[:id])
    halt 404, json(error: 'Not found') unless result
    json serialize(result)
  end

  post '/pizzas' do
    attrs = JSON.parse(request.body.read, symbolize_names: true)
    result = Pizza.create(**attrs)
    status 201
    json serialize(result)
  end

  delete '/pizzas/:id' do
    Pizza.delete(params[:id])
    json deleted: params[:id]
  end

  get '/orders/pending' do
    json Order.pending.map { |r| serialize(r) }
  end

  get '/orders' do
    json Order.all.map { |r| serialize(r) }
  end

  get '/orders/:id' do
    result = Order.find(params[:id])
    halt 404, json(error: 'Not found') unless result
    json serialize(result)
  end

  delete '/orders/:id' do
    Order.delete(params[:id])
    json deleted: params[:id]
  end

  private

  def serialize(obj)
    Hecks::Utils.object_attr_names(obj).each_with_object({}) do |name, h|
      next unless obj.respond_to?(name)
      val = obj.send(name)
      h[name] = val.is_a?(Time) ? val.iso8601 : val
    end
  end
end
