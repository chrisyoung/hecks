require_relative "ui"

module PizzasDomain
  module Server
    module UIRoutes
      include UI

      def mount_ui_routes(server)
        nav = [{:label=>"Home", :href=>"/"}, {:label=>"Pizzas", :href=>"/pizzas"}, {:label=>"Orders", :href=>"/orders"}, {:label=>"Config", :href=>"/config"}]

        server.mount_proc "/" do |req, res|
          next unless req.path == "/"
          html_response(res, layout(title: "PizzasDomain", nav_items: nav) {
            "<h1>PizzasDomain</h1><div style='display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:1rem'><a href='/pizzas' style='text-decoration:none'><div style='background:#fff;padding:1.5rem;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,0.1)'><h2>Pizzas</h2><p class='mono'>2 commands · 3 attributes</p></div></a><a href='/orders' style='text-decoration:none'><div style='background:#fff;padding:1.5rem;border-radius:8px;box-shadow:0 1px 3px rgba(0,0,0,0.1)'><h2>Orders</h2><p class='mono'>2 commands · 3 attributes</p></div></a></div>"
          })
        end

        server.mount_proc "/pizzas" do |req, res|
          next unless req.path == "/pizzas"
          items = Pizza.all
          rows = items.map { |obj| "<tr>" + "<td class='mono'><a href='/pizzas/show?id=" + obj.id + "'>" + h(obj.id[0..7]) + "...</a></td>" + "<td>" + h(obj.name) + "</td>" + "<td>" + h(obj.description) + "</td>" + "<td>" + obj.toppings.size.to_s + " items</td>" + "<td>" + (PizzasDomain.role_allows?("Pizza", "add_topping") ? "<a class='btn btn-sm' href='/pizzas/add_topping/new?id=" + obj.id + "'>AddTopping</a> " : "<a class='btn btn-sm' href='/pizzas/add_topping/new?id=" + obj.id + "' style='opacity:0.4'>AddTopping</a> ") + "</td>" + "</tr>" }.join
          html_response(res, layout(title: "Pizzas — PizzasDomain", nav_items: nav) {
            "<div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem'><h1>Pizzas (" + items.size.to_s + ")</h1><div>" + (PizzasDomain.role_allows?("Pizza", "create_pizza") ? "<a class='btn' href='/pizzas/create_pizza/new'>CreatePizza</a> " : "<a class='btn' href='/pizzas/create_pizza/new' style='opacity:0.4'>CreatePizza</a> ") + "</div></div>" \
            "<table><thead><tr><th>ID</th><th>Name</th><th>Description</th><th>Toppings</th><th>Actions</th></tr></thead><tbody>" + rows + "</tbody></table>"
          })
        end

        server.mount_proc "/orders" do |req, res|
          next unless req.path == "/orders"
          items = Order.all
          rows = items.map { |obj| "<tr>" + "<td class='mono'><a href='/orders/show?id=" + obj.id + "'>" + h(obj.id[0..7]) + "...</a></td>" + "<td>" + h(obj.customer_name) + "</td>" + "<td>" + obj.items.size.to_s + " items</td>" + "<td>" + h(obj.status) + "</td>" + "<td>" + (PizzasDomain.role_allows?("Order", "cancel_order") ? "<a class='btn btn-sm' href='/orders/cancel_order/new?id=" + obj.id + "'>CancelOrder</a> " : "<a class='btn btn-sm' href='/orders/cancel_order/new?id=" + obj.id + "' style='opacity:0.4'>CancelOrder</a> ") + "</td>" + "</tr>" }.join
          html_response(res, layout(title: "Orders — PizzasDomain", nav_items: nav) {
            "<div style='display:flex;justify-content:space-between;align-items:center;margin-bottom:1rem'><h1>Orders (" + items.size.to_s + ")</h1><div>" + (PizzasDomain.role_allows?("Order", "place_order") ? "<a class='btn' href='/orders/place_order/new'>PlaceOrder</a> " : "<a class='btn' href='/orders/place_order/new' style='opacity:0.4'>PlaceOrder</a> ") + "</div></div>" \
            "<table><thead><tr><th>ID</th><th>Customer Name</th><th>Items</th><th>Status</th><th>Actions</th></tr></thead><tbody>" + rows + "</tbody></table>"
          })
        end

        server.mount_proc "/pizzas/show" do |req, res|
          obj = Pizza.find(req.query["id"])
          unless obj
            res.status = 404; html_response(res, "Not found"); next
          end
          html_response(res, layout(title: "Pizza — PizzasDomain", nav_items: nav) {
            "<h1>Pizza</h1><div class='detail'><dl><dt>ID</dt><dd class='mono'>" + h(obj.id) + "</dd>" + "<dt>name</dt><dd>" + h(obj.name) + "</dd>" + "<dt>description</dt><dd>" + h(obj.description) + "</dd>" + "<dt>toppings</dt><dd>" + (obj.toppings.empty? ? "(none)" : "<ul>" + obj.toppings.map { |v| "<li>" + v.name.to_s + " — " + v.amount.to_s + "</li>" }.join + "</ul>") + "</dd>" + "</dl></div>" \
            "<div class='actions'><a href='/pizzas' class='btn btn-sm'>Back</a> " + (PizzasDomain.role_allows?("Pizza", "add_topping") ? "<a class='btn btn-sm' href='/pizzas/add_topping/new?id=" + obj.id + "'>AddTopping</a> " : "<a class='btn btn-sm' href='/pizzas/add_topping/new?id=" + obj.id + "' style='opacity:0.4'>AddTopping</a> ") + (PizzasDomain.role_allows?("Order", "place_order") ? "<a class='btn btn-sm' href='/orders/place_order/new?id=" + obj.id + "'>PlaceOrder</a> " : "<a class='btn btn-sm' href='/orders/place_order/new?id=" + obj.id + "' style='opacity:0.4'>PlaceOrder</a> ") + "</div>"
          })
        end

        server.mount_proc "/orders/show" do |req, res|
          obj = Order.find(req.query["id"])
          unless obj
            res.status = 404; html_response(res, "Not found"); next
          end
          html_response(res, layout(title: "Order — PizzasDomain", nav_items: nav) {
            "<h1>Order</h1><div class='detail'><dl><dt>ID</dt><dd class='mono'>" + h(obj.id) + "</dd>" + "<dt>customer_name</dt><dd>" + h(obj.customer_name) + "</dd>" + "<dt>items</dt><dd>" + (obj.items.empty? ? "(none)" : "<ul>" + obj.items.map { |v| "<li>" + v.pizza_id.to_s + " — " + v.quantity.to_s + "</li>" }.join + "</ul>") + "</dd>" + "<dt>status</dt><dd>" + h(obj.status) + "</dd>" + "</dl></div>" \
            "<div class='actions'><a href='/orders' class='btn btn-sm'>Back</a> " + (PizzasDomain.role_allows?("Order", "cancel_order") ? "<a class='btn btn-sm' href='/orders/cancel_order/new?id=" + obj.id + "'>CancelOrder</a> " : "<a class='btn btn-sm' href='/orders/cancel_order/new?id=" + obj.id + "' style='opacity:0.4'>CancelOrder</a> ") + "</div>"
          })
        end

        server.mount_proc "/pizzas/create_pizza/new" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "create_pizza")
            html_response(res, layout(title: "Denied — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>Role '" + PizzasDomain.current_role.to_s + "' cannot create_pizza</div><a href='/pizzas' class='btn'>Back</a>"
            }); next
          end
          html_response(res, layout(title: "CreatePizza — PizzasDomain", nav_items: nav) {
            "<h1>CreatePizza</h1><form method='post' action='/pizzas/create_pizza/submit'>" + "<label>Name<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='name' type='text' required>" + "<label>Description<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='description' type='text' required>" + "<button class='btn' type='submit'>CreatePizza</button></form>"
          })
        end

        server.mount_proc "/pizzas/create_pizza/submit" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "create_pizza")
            res.status = 403; html_response(res, "Forbidden"); next
          end
          begin
            params = req.query
            result = Pizza.create_pizza(name: params["name"], description: params["description"])
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/pizzas/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            error_field = e.respond_to?(:field) ? e.field.to_s : nil
            error_html = error_field ? "" : "<div class='flash flash-error'>" + h(e.message) + "</div>"
            html_response(res, layout(title: "CreatePizza — PizzasDomain", nav_items: nav) {
              "<h1>CreatePizza</h1>" + error_html + "<form method='post' action='/pizzas/create_pizza/submit'>" + "<label>Name</label><input name='name' type='text' value='" + h(params["name"] || "") + "' required>" + (error_field == "name" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<label>Description</label><input name='description' type='text' value='" + h(params["description"] || "") + "' required>" + (error_field == "description" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<button class='btn' type='submit'>CreatePizza</button></form>"
            })
          rescue PizzasDomain::Error => e
            html_response(res, layout(title: "Error — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>" + h(e.message) + "</div><a href='/pizzas/create_pizza/new' class='btn'>Try again</a>"
            })
          end
        end

        server.mount_proc "/pizzas/add_topping/new" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "add_topping")
            html_response(res, layout(title: "Denied — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>Role '" + PizzasDomain.current_role.to_s + "' cannot add_topping</div><a href='/pizzas' class='btn'>Back</a>"
            }); next
          end
          html_response(res, layout(title: "AddTopping — PizzasDomain", nav_items: nav) {
            "<h1>AddTopping</h1><form method='post' action='/pizzas/add_topping/submit'>" + "<input type='hidden' name='pizza_id' value='" + h(req.query["id"] || "") + "'>" + "<label>Name<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='name' type='text' required>" + "<label>Amount<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='amount' type='number' required>" + "<button class='btn' type='submit'>AddTopping</button></form>"
          })
        end

        server.mount_proc "/pizzas/add_topping/submit" do |req, res|
          unless PizzasDomain.role_allows?("Pizza", "add_topping")
            res.status = 403; html_response(res, "Forbidden"); next
          end
          begin
            params = req.query
            result = Pizza.add_topping(pizza_id: params["pizza_id"], name: params["name"], amount: params["amount"].to_i)
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/pizzas/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            error_field = e.respond_to?(:field) ? e.field.to_s : nil
            error_html = error_field ? "" : "<div class='flash flash-error'>" + h(e.message) + "</div>"
            html_response(res, layout(title: "AddTopping — PizzasDomain", nav_items: nav) {
              "<h1>AddTopping</h1>" + error_html + "<form method='post' action='/pizzas/add_topping/submit'>" + "<input type='hidden' name='pizza_id' value='" + h(params["pizza_id"] || "") + "'>" + "<label>Name</label><input name='name' type='text' value='" + h(params["name"] || "") + "' required>" + (error_field == "name" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<label>Amount</label><input name='amount' type='number' value='" + h(params["amount"] || "") + "' required>" + (error_field == "amount" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<button class='btn' type='submit'>AddTopping</button></form>"
            })
          rescue PizzasDomain::Error => e
            html_response(res, layout(title: "Error — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>" + h(e.message) + "</div><a href='/pizzas/add_topping/new' class='btn'>Try again</a>"
            })
          end
        end

        server.mount_proc "/orders/place_order/new" do |req, res|
          unless PizzasDomain.role_allows?("Order", "place_order")
            html_response(res, layout(title: "Denied — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>Role '" + PizzasDomain.current_role.to_s + "' cannot place_order</div><a href='/orders' class='btn'>Back</a>"
            }); next
          end
          html_response(res, layout(title: "PlaceOrder — PizzasDomain", nav_items: nav) {
            "<h1>PlaceOrder</h1><form method='post' action='/orders/place_order/submit'>" + "<label>Customer Name<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='customer_name' type='text' required>" + "<label>Pizza<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><select name='pizza_id' required>" + Pizza.all.map { |r| selected = r.id == req.query["id"] ? " selected" : ""; "<option value='" + r.id + "'" + selected + ">" + r.name.to_s + "</option>" }.join + "</select>" + "<label>Quantity<span style='color:#999;font-size:0.75rem;font-weight:normal;margin-left:0.25rem'>required</span></label><input name='quantity' type='number' required>" + "<button class='btn' type='submit'>PlaceOrder</button></form>"
          })
        end

        server.mount_proc "/orders/place_order/submit" do |req, res|
          unless PizzasDomain.role_allows?("Order", "place_order")
            res.status = 403; html_response(res, "Forbidden"); next
          end
          begin
            params = req.query
            result = Order.place_order(customer_name: params["customer_name"], pizza_id: params["pizza_id"], quantity: params["quantity"].to_i)
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/orders/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            error_field = e.respond_to?(:field) ? e.field.to_s : nil
            error_html = error_field ? "" : "<div class='flash flash-error'>" + h(e.message) + "</div>"
            html_response(res, layout(title: "PlaceOrder — PizzasDomain", nav_items: nav) {
              "<h1>PlaceOrder</h1>" + error_html + "<form method='post' action='/orders/place_order/submit'>" + "<label>Customer Name</label><input name='customer_name' type='text' value='" + h(params["customer_name"] || "") + "' required>" + (error_field == "customer_name" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<label>Pizza Id</label><select name='pizza_id' required>" + Pizza.all.map { |r| sel = r.id == params["pizza_id"] ? " selected" : ""; "<option value='" + r.id + "'" + sel + ">" + r.name.to_s + "</option>" }.join + "</select>" + (error_field == "pizza_id" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<label>Quantity</label><input name='quantity' type='number' value='" + h(params["quantity"] || "") + "' required>" + (error_field == "quantity" ? "<div style='color:#c0392b;font-size:0.85rem;margin:-0.5rem 0 0.5rem'>" + h(e.message) + "</div>" : "") + "<button class='btn' type='submit'>PlaceOrder</button></form>"
            })
          rescue PizzasDomain::Error => e
            html_response(res, layout(title: "Error — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>" + h(e.message) + "</div><a href='/orders/place_order/new' class='btn'>Try again</a>"
            })
          end
        end

        server.mount_proc "/orders/cancel_order/new" do |req, res|
          unless PizzasDomain.role_allows?("Order", "cancel_order")
            html_response(res, layout(title: "Denied — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>Role '" + PizzasDomain.current_role.to_s + "' cannot cancel_order</div><a href='/orders' class='btn'>Back</a>"
            }); next
          end
          html_response(res, layout(title: "CancelOrder — PizzasDomain", nav_items: nav) {
            "<h1>CancelOrder</h1><form method='post' action='/orders/cancel_order/submit'>" + "<input type='hidden' name='order_id' value='" + h(req.query["id"] || "") + "'>" + "<button class='btn' type='submit'>CancelOrder</button></form>"
          })
        end

        server.mount_proc "/orders/cancel_order/submit" do |req, res|
          unless PizzasDomain.role_allows?("Order", "cancel_order")
            res.status = 403; html_response(res, "Forbidden"); next
          end
          begin
            params = req.query
            result = Order.cancel_order(order_id: params["order_id"])
            res.set_redirect(WEBrick::HTTPStatus::SeeOther, "/orders/show?id=" + result.aggregate.id)
          rescue PizzasDomain::ValidationError => e
            error_field = e.respond_to?(:field) ? e.field.to_s : nil
            error_html = error_field ? "" : "<div class='flash flash-error'>" + h(e.message) + "</div>"
            html_response(res, layout(title: "CancelOrder — PizzasDomain", nav_items: nav) {
              "<h1>CancelOrder</h1>" + error_html + "<form method='post' action='/orders/cancel_order/submit'>" + "<input type='hidden' name='order_id' value='" + h(params["order_id"] || "") + "'>" + "<button class='btn' type='submit'>CancelOrder</button></form>"
            })
          rescue PizzasDomain::Error => e
            html_response(res, layout(title: "Error — PizzasDomain", nav_items: nav) {
              "<div class='flash flash-error'>" + h(e.message) + "</div><a href='/orders/cancel_order/new' class='btn'>Try again</a>"
            })
          end
        end

        server.mount_proc "/config" do |req, res|
          next unless req.request_method == "GET"
          cfg = PizzasDomain.config || {}
          rows = "<tr><td><a href='/pizzas'>Pizza</a></td>" + "<td>" + Pizza.count.to_s + "</td>" + "<td class='mono'>CreatePizza, AddTopping</td>" + "<td class='mono'>admin: find, all, create_pizza, add_topping | customer: find, all</td></tr>" + "<tr><td><a href='/orders'>Order</a></td>" + "<td>" + Order.count.to_s + "</td>" + "<td class='mono'>PlaceOrder, CancelOrder</td>" + "<td class='mono'>admin: find, all, place_order, cancel_order | customer: find, all, place_order</td></tr>"
          adapters = %w[memory sqlite].map { |a|
            selected = cfg[:adapter].to_s == a ? " selected" : ""
            "<option value='" + a + "'" + selected + ">" + a + "</option>"
          }.join
          roles = PizzasDomain::ROLES.map { |r|
            selected = PizzasDomain.current_role.to_s == r ? " selected" : ""
            "<option value='" + r + "'" + selected + ">" + r + "</option>"
          }.join
          html_response(res, layout(title: "Config — PizzasDomain", nav_items: nav) {
            "<h1>Configuration</h1>" \
            "<div class='detail'><dl>" \
            "<dt>Role</dt><dd><form method='post' action='/config/role' style='display:inline;background:none;padding:0;box-shadow:none'>" \
            "<select name='role' style='width:auto;display:inline;margin:0'>" + roles + "</select> " \
            "<button class='btn btn-sm' type='submit'>Switch</button></form></dd>" \
            "<dt>Adapter</dt><dd><form method='post' action='/config/reboot' style='display:inline;background:none;padding:0;box-shadow:none'>" \
            "<select name='adapter' style='width:auto;display:inline;margin:0'>" + adapters + "</select> " \
            "<button class='btn btn-sm' type='submit'>Switch</button></form></dd>" \
            "<dt>Events</dt><dd>" + PizzasDomain.events.size.to_s + " total</dd>" \
            "<dt>Booted</dt><dd>" + (cfg[:booted_at] || "unknown").to_s + "</dd>" \
            "<dt>Policies</dt><dd>(none)</dd>" \
            "</dl></div>" \
            "<h2 style='margin-top:2rem'>Aggregates</h2>" \
            "<table><thead><tr><th>Aggregate</th><th>Count</th><th>Commands</th><th>Ports</th></tr></thead><tbody>" + rows + "</tbody></table>"
          })
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
