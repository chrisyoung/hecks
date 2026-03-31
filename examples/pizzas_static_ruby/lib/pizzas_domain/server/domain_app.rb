require_relative "../runtime/errors"
require_relative "server"
require_relative "ui_routes"

module PizzasDomain
  module Server
    class DomainApp < App
      include UIRoutes

      private

      def mount_routes(server)
        server.mount_proc "/pizzas" do |req, res|
          if req.request_method == "GET"
            items = Pizza.all.map { |obj| aggregate_to_hash(obj) }
            json_response(res, items)
          else
            res.status = 405
          end
        end

        server.mount_proc "/pizzas/find" do |req, res|
          id = req.query["id"]
          obj = Pizza.find(id)
          if obj
            json_response(res, aggregate_to_hash(obj))
          else
            json_error(res, { error: "NotFound", message: "Pizza not found" }, status: 404)
          end
        end

        server.mount_proc "/pizzas/create_pizza" do |req, res|
          begin
            attrs = parse_body(req)
            error = PizzasDomain::Validations.check("Pizza", "create_pizza", attrs)
            raise error if error
            result = Pizza.create_pizza(**attrs)
            json_response(res, aggregate_to_hash(result.aggregate), status: 201)
          rescue PizzasDomain::Error => e
            json_error(res, e)
          end
        end

        server.mount_proc "/pizzas/add_topping" do |req, res|
          begin
            attrs = parse_body(req)
            error = PizzasDomain::Validations.check("Pizza", "add_topping", attrs)
            raise error if error
            result = Pizza.add_topping(**attrs)
            json_response(res, aggregate_to_hash(result.aggregate), status: 201)
          rescue PizzasDomain::Error => e
            json_error(res, e)
          end
        end

        server.mount_proc "/orders" do |req, res|
          if req.request_method == "GET"
            items = Order.all.map { |obj| aggregate_to_hash(obj) }
            json_response(res, items)
          else
            res.status = 405
          end
        end

        server.mount_proc "/orders/find" do |req, res|
          id = req.query["id"]
          obj = Order.find(id)
          if obj
            json_response(res, aggregate_to_hash(obj))
          else
            json_error(res, { error: "NotFound", message: "Order not found" }, status: 404)
          end
        end

        server.mount_proc "/orders/place_order" do |req, res|
          begin
            attrs = parse_body(req)
            error = PizzasDomain::Validations.check("Order", "place_order", attrs)
            raise error if error
            result = Order.place_order(**attrs)
            json_response(res, aggregate_to_hash(result.aggregate), status: 201)
          rescue PizzasDomain::Error => e
            json_error(res, e)
          end
        end

        server.mount_proc "/orders/cancel_order" do |req, res|
          begin
            attrs = parse_body(req)
            error = PizzasDomain::Validations.check("Order", "cancel_order", attrs)
            raise error if error
            result = Order.cancel_order(**attrs)
            json_response(res, aggregate_to_hash(result.aggregate), status: 201)
          rescue PizzasDomain::Error => e
            json_error(res, e)
          end
        end

        server.mount_proc "/_openapi" do |req, res|
          json_response(res, {"openapi"=>"3.0.0", "info"=>{"title"=>"PizzasDomain"}, "paths"=>{"/pizzas"=>{"get"=>{"summary"=>"List all pizzas"}}, "/pizzas/find"=>{"get"=>{"summary"=>"Find Pizza by ID"}}, "/pizzas/create_pizza"=>{"post"=>{"summary"=>"CreatePizza", "parameters"=>[{"name"=>"name", "type"=>"String"}, {"name"=>"description", "type"=>"String"}]}}, "/pizzas/add_topping"=>{"post"=>{"summary"=>"AddTopping", "parameters"=>[{"name"=>"pizza", "type"=>"Pizza"}, {"name"=>"name", "type"=>"String"}, {"name"=>"amount", "type"=>"Integer"}]}}, "/orders"=>{"get"=>{"summary"=>"List all orders"}}, "/orders/find"=>{"get"=>{"summary"=>"Find Order by ID"}}, "/orders/place_order"=>{"post"=>{"summary"=>"PlaceOrder", "parameters"=>[{"name"=>"customer_name", "type"=>"String"}, {"name"=>"pizza", "type"=>"String"}, {"name"=>"quantity", "type"=>"Integer"}]}}, "/orders/cancel_order"=>{"post"=>{"summary"=>"CancelOrder", "parameters"=>[{"name"=>"order", "type"=>"Order"}]}}}})
        end

        server.mount_proc "/_validations" do |req, res|
          json_response(res, PizzasDomain::Validations.rules || {})
        end
        mount_ui_routes(server)
      end
    end
  end
end
