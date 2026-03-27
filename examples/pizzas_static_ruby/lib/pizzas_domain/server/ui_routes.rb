require "erb"
require_relative "renderer"

module PizzasDomain
  module Server
    module UIRoutes

      def mount_ui_routes(server)
        views = File.expand_path("views", __dir__)
        renderer = Renderer.new(views)
        nav = [{:label=>"Home", :href=>"/"}, {:label=>"Pizzas", :href=>"/pizzas"}, {:label=>"Orders", :href=>"/orders"}, {:label=>"Config", :href=>"/config"}]
        brand = "PizzasDomain"

        server.mount_proc "/" do |req, res|
          next unless req.path == "/"
          html = renderer.render(:home, title: "PizzasDomain", brand: brand, nav_items: nav,
            domain_name: "PizzasDomain", aggregates: [{ name: "Pizzas", href: "/pizzas", commands: 2, attributes: 3 }, { name: "Orders", href: "/orders", commands: 2, attributes: 3 }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/pizzas" do |req, res|
          next unless req.path == "/pizzas"
          all_items = Pizza.all
          items = all_items.map { |obj| { id: obj.id, short_id: obj.id[0..7] + "...", show_href: "/pizzas/show?id=" + obj.id, cells: [obj.name.to_s, obj.description.to_s, obj.toppings.size.to_s + " items"] } }
          html = renderer.render(:index, title: "Pizzas — PizzasDomain", brand: brand, nav_items: nav,
            aggregate_name: "Pizza", items: items,
            columns: [{ label: "Name" }, { label: "Description" }, { label: "Toppings" }],
            buttons: [{ label: "CreatePizza", href: "/pizzas/create_pizza/new", allowed: PizzasDomain.role_allows?("Pizza", "create_pizza") }],
            row_actions: [{ label: "AddTopping", href_prefix: "/pizzas/add_topping/new?id=", allowed: PizzasDomain.role_allows?("Pizza", "add_topping") }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/orders" do |req, res|
          next unless req.path == "/orders"
          all_items = Order.all
          items = all_items.map { |obj| { id: obj.id, short_id: obj.id[0..7] + "...", show_href: "/orders/show?id=" + obj.id, cells: [obj.customer_name.to_s, obj.items.size.to_s + " items", obj.status.to_s] } }
          html = renderer.render(:index, title: "Orders — PizzasDomain", brand: brand, nav_items: nav,
            aggregate_name: "Order", items: items,
            columns: [{ label: "Customer Name" }, { label: "Items" }, { label: "Status" }],
            buttons: [{ label: "PlaceOrder", href: "/orders/place_order/new", allowed: PizzasDomain.role_allows?("Order", "place_order") }],
            row_actions: [{ label: "CancelOrder", href_prefix: "/orders/cancel_order/new?id=", allowed: PizzasDomain.role_allows?("Order", "cancel_order") }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/pizzas/show" do |req, res|
          obj = Pizza.find(req.query["id"])
          unless obj
            res.status = 404; res.body = "Not found"; next
          end
          html = renderer.render(:show, title: "Pizza — PizzasDomain", brand: brand, nav_items: nav,
            aggregate_name: "Pizza", back_href: "/pizzas",
            item: { id: obj.id, fields: [{ label: "Name", value: obj.name.to_s }, { label: "Description", value: obj.description.to_s }, { label: "Toppings", type: :list, items: obj.toppings.map { |v| v.name.to_s + " — " + v.amount.to_s } }] },
            buttons: [{ label: "AddTopping", href: "/pizzas/add_topping/new?id=" + obj.id, allowed: PizzasDomain.role_allows?("Pizza", "add_topping") }, { label: "PlaceOrder", href: "/orders/place_order/new?id=" + obj.id, allowed: PizzasDomain.role_allows?("Order", "place_order") }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/orders/show" do |req, res|
          obj = Order.find(req.query["id"])
          unless obj
            res.status = 404; res.body = "Not found"; next
          end
          html = renderer.render(:show, title: "Order — PizzasDomain", brand: brand, nav_items: nav,
            aggregate_name: "Order", back_href: "/orders",
            item: { id: obj.id, fields: [{ label: "Customer Name", value: obj.customer_name.to_s }, { label: "Items", type: :list, items: obj.items.map { |v| v.pizza_id.to_s + " — " + v.quantity.to_s } }, { label: "Status", value: obj.status.to_s }] },
            buttons: [{ label: "CancelOrder", href: "/orders/cancel_order/new?id=" + obj.id, allowed: PizzasDomain.role_allows?("Order", "cancel_order") }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/pizzas/create_pizza/new" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "create_pizza")
            html = renderer.render(:form, title: "Denied — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CreatePizza", action: "", error_message: "Role '" + PizzasDomain.current_role.to_s + "' cannot create_pizza", fields: [])
            res["Content-Type"] = "text/html"; res.body = html; next
          end
          fields = [{ type: :input, name: "name", label: "Name", input_type: "text", step: false, required: true, value: "" }, { type: :input, name: "description", label: "Description", input_type: "text", step: false, required: true, value: "" }]
          html = renderer.render(:form, title: "CreatePizza — PizzasDomain", brand: brand, nav_items: nav,
            command_name: "CreatePizza", action: "/pizzas/create_pizza/submit", error_message: nil, fields: fields)
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/pizzas/create_pizza/submit" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "create_pizza")
            res.status = 403; res.body = "Forbidden"; next
          end
          begin
            params = req.query
            result = Pizza.create_pizza(name: params["name"], description: params["description"])
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/pizzas/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            fields = [{ type: :input, name: "name", label: "Name", input_type: "text", step: false, required: true, value: "" }, { type: :input, name: "description", label: "Description", input_type: "text", step: false, required: true, value: "" }]
            fields.each { |f| f[:value] = params[f[:name]] || f[:value] if f[:type] != :hidden }
            fields.each { |f| f[:error] = e.message if e.respond_to?(:field) && e.field.to_s == f[:name] }
            html = renderer.render(:form, title: "CreatePizza — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CreatePizza", action: "/pizzas/create_pizza/submit",
              error_message: (e.respond_to?(:field) && e.field ? nil : e.message), fields: fields)
            res["Content-Type"] = "text/html"; res.body = html
          rescue PizzasDomain::Error => e
            html = renderer.render(:form, title: "Error — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CreatePizza", action: "/pizzas/create_pizza/new",
              error_message: e.message, fields: [])
            res["Content-Type"] = "text/html"; res.body = html
          end
        end

        server.mount_proc "/pizzas/add_topping/new" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "add_topping")
            html = renderer.render(:form, title: "Denied — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "AddTopping", action: "", error_message: "Role '" + PizzasDomain.current_role.to_s + "' cannot add_topping", fields: [])
            res["Content-Type"] = "text/html"; res.body = html; next
          end
          fields = [{ type: :hidden, name: "pizza_id", value: req.query["id"] || "" }, { type: :input, name: "name", label: "Name", input_type: "text", step: false, required: true, value: "" }, { type: :input, name: "amount", label: "Amount", input_type: "number", step: false, required: true, value: "" }]
          html = renderer.render(:form, title: "AddTopping — PizzasDomain", brand: brand, nav_items: nav,
            command_name: "AddTopping", action: "/pizzas/add_topping/submit", error_message: nil, fields: fields)
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/pizzas/add_topping/submit" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "add_topping")
            res.status = 403; res.body = "Forbidden"; next
          end
          begin
            params = req.query
            result = Pizza.add_topping(pizza_id: params["pizza_id"], name: params["name"], amount: params["amount"].to_i)
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/pizzas/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            fields = [{ type: :hidden, name: "pizza_id", value: req.query["id"] || "" }, { type: :input, name: "name", label: "Name", input_type: "text", step: false, required: true, value: "" }, { type: :input, name: "amount", label: "Amount", input_type: "number", step: false, required: true, value: "" }]
            fields.each { |f| f[:value] = params[f[:name]] || f[:value] if f[:type] != :hidden }
            fields.each { |f| f[:error] = e.message if e.respond_to?(:field) && e.field.to_s == f[:name] }
            html = renderer.render(:form, title: "AddTopping — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "AddTopping", action: "/pizzas/add_topping/submit",
              error_message: (e.respond_to?(:field) && e.field ? nil : e.message), fields: fields)
            res["Content-Type"] = "text/html"; res.body = html
          rescue PizzasDomain::Error => e
            html = renderer.render(:form, title: "Error — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "AddTopping", action: "/pizzas/add_topping/new",
              error_message: e.message, fields: [])
            res["Content-Type"] = "text/html"; res.body = html
          end
        end

        server.mount_proc "/orders/place_order/new" do |req, res|
          unless PizzasDomain.role_allows?("Order", "place_order")
            html = renderer.render(:form, title: "Denied — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "PlaceOrder", action: "", error_message: "Role '" + PizzasDomain.current_role.to_s + "' cannot place_order", fields: [])
            res["Content-Type"] = "text/html"; res.body = html; next
          end
          fields = [{ type: :input, name: "customer_name", label: "Customer Name", input_type: "text", step: false, required: true, value: "" }, { type: :select, name: "pizza_id", label: "Pizza", required: true, options: Pizza.all.map { |r| { value: r.id, label: r.name.to_s, selected: r.id == req.query["id"] } } }, { type: :input, name: "quantity", label: "Quantity", input_type: "number", step: false, required: true, value: "" }]
          html = renderer.render(:form, title: "PlaceOrder — PizzasDomain", brand: brand, nav_items: nav,
            command_name: "PlaceOrder", action: "/orders/place_order/submit", error_message: nil, fields: fields)
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/orders/place_order/submit" do |req, res|
          unless PizzasDomain.role_allows?("Order", "place_order")
            res.status = 403; res.body = "Forbidden"; next
          end
          begin
            params = req.query
            result = Order.place_order(customer_name: params["customer_name"], pizza_id: params["pizza_id"], quantity: params["quantity"].to_i)
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/orders/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            fields = [{ type: :input, name: "customer_name", label: "Customer Name", input_type: "text", step: false, required: true, value: "" }, { type: :select, name: "pizza_id", label: "Pizza", required: true, options: Pizza.all.map { |r| { value: r.id, label: r.name.to_s, selected: r.id == req.query["id"] } } }, { type: :input, name: "quantity", label: "Quantity", input_type: "number", step: false, required: true, value: "" }]
            fields.each { |f| f[:value] = params[f[:name]] || f[:value] if f[:type] != :hidden }
            fields.each { |f| f[:error] = e.message if e.respond_to?(:field) && e.field.to_s == f[:name] }
            html = renderer.render(:form, title: "PlaceOrder — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "PlaceOrder", action: "/orders/place_order/submit",
              error_message: (e.respond_to?(:field) && e.field ? nil : e.message), fields: fields)
            res["Content-Type"] = "text/html"; res.body = html
          rescue PizzasDomain::Error => e
            html = renderer.render(:form, title: "Error — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "PlaceOrder", action: "/orders/place_order/new",
              error_message: e.message, fields: [])
            res["Content-Type"] = "text/html"; res.body = html
          end
        end

        server.mount_proc "/orders/cancel_order/new" do |req, res|
          unless PizzasDomain.role_allows?("Order", "cancel_order")
            html = renderer.render(:form, title: "Denied — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CancelOrder", action: "", error_message: "Role '" + PizzasDomain.current_role.to_s + "' cannot cancel_order", fields: [])
            res["Content-Type"] = "text/html"; res.body = html; next
          end
          fields = [{ type: :hidden, name: "order_id", value: req.query["id"] || "" }]
          html = renderer.render(:form, title: "CancelOrder — PizzasDomain", brand: brand, nav_items: nav,
            command_name: "CancelOrder", action: "/orders/cancel_order/submit", error_message: nil, fields: fields)
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/orders/cancel_order/submit" do |req, res|
          unless PizzasDomain.role_allows?("Order", "cancel_order")
            res.status = 403; res.body = "Forbidden"; next
          end
          begin
            params = req.query
            result = Order.cancel_order(order_id: params["order_id"])
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/orders/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            fields = [{ type: :hidden, name: "order_id", value: req.query["id"] || "" }]
            fields.each { |f| f[:value] = params[f[:name]] || f[:value] if f[:type] != :hidden }
            fields.each { |f| f[:error] = e.message if e.respond_to?(:field) && e.field.to_s == f[:name] }
            html = renderer.render(:form, title: "CancelOrder — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CancelOrder", action: "/orders/cancel_order/submit",
              error_message: (e.respond_to?(:field) && e.field ? nil : e.message), fields: fields)
            res["Content-Type"] = "text/html"; res.body = html
          rescue PizzasDomain::Error => e
            html = renderer.render(:form, title: "Error — PizzasDomain", brand: brand, nav_items: nav,
              command_name: "CancelOrder", action: "/orders/cancel_order/new",
              error_message: e.message, fields: [])
            res["Content-Type"] = "text/html"; res.body = html
          end
        end

        server.mount_proc "/config" do |req, res|
          next unless req.request_method == "GET"
          cfg = PizzasDomain.config || {}
          html = renderer.render(:config, title: "Config — PizzasDomain", brand: brand, nav_items: nav,
            roles: PizzasDomain::ROLES, current_role: PizzasDomain.current_role.to_s,
            adapters: %w[memory filesystem sqlite], current_adapter: cfg[:adapter].to_s,
            event_count: PizzasDomain.events.size, booted_at: (cfg[:booted_at] || "unknown").to_s,
            policies: [],
            aggregate_rows: [{ name: "Pizza", href: "/pizzas", count: Pizza.count, commands: "CreatePizza, AddTopping", ports: "admin: find, all, create_pizza, add_topping | customer: find, all" }, { name: "Order", href: "/orders", count: Order.count, commands: "PlaceOrder, CancelOrder", ports: "admin: find, all, place_order, cancel_order | customer: find, all, place_order" }])
          res["Content-Type"] = "text/html"; res.body = html
        end

        server.mount_proc "/config/reboot" do |req, res|
          adapter = (req.query["adapter"] || "memory").to_sym
          PizzasDomain.reboot(adapter: adapter)
          res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/config")
        end

        server.mount_proc "/config/role" do |req, res|
          PizzasDomain.current_role = req.query["role"] || PizzasDomain.current_role
          res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/config")
        end

      end
    end
  end
end
