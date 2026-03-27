package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"pizzas_domain/domain"
	"pizzas_domain/adapters/memory"
)

type App struct {
	PizzaRepo domain.PizzaRepository
	OrderRepo domain.OrderRepository
}

func NewApp() *App {
	return &App{
		PizzaRepo: memory.NewPizzaMemoryRepository(),
		OrderRepo: memory.NewOrderMemoryRepository(),
	}
}

func (app *App) Start(port int) error {
	mux := http.NewServeMux()

	// Template renderer
	exe, _ := os.Executable()
	viewsDir := filepath.Join(filepath.Dir(exe), "..", "views")
	if _, err := os.Stat(viewsDir); err != nil {
		viewsDir = "views" // fallback to current directory
	}
	nav := []NavItem{
		{Label: "Home", Href: "/"},
		{Label: "Pizzas", Href: "/pizzas"},
		{Label: "Orders", Href: "/orders"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "PizzasDomain", nav)

	// Home
	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "PizzasDomain", HomeData{
			DomainName: "PizzasDomain",
			Aggregates: []HomeAgg{{Name: "Pizzas", Href: "/pizzas", Commands: 2, Attributes: 3}, {Name: "Orders", Href: "/orders", Commands: 2, Attributes: 3}},
		})
	})

	mux.HandleFunc("GET /pizzas", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.PizzaRepo.All()
			jsonResponse(w, items)
			return
		}
		// HTML index
		type Col struct { Label string }
		type Item struct { ID string; ShortID string; ShowHref string; Cells []string }
		type Btn struct { Label string; Href string; Allowed bool }
		type IndexData struct { AggregateName string; Items []Item; Columns []Col; Buttons []Btn }
		items, _ := app.PizzaRepo.All()
		var rows []Item
		for _, obj := range items {
			shortID := obj.ID
			if len(shortID) > 8 { shortID = shortID[:8] + "..." }
			rows = append(rows, Item{ID: obj.ID, ShortID: shortID, ShowHref: "/pizzas/show?id=" + obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%d items", len(obj.Toppings))}})
		}
		renderer.Render(w, "index", "Pizzas", IndexData{
			AggregateName: "Pizza",
			Items: rows,
			Columns: []Col{{Label: "Name"}, {Label: "Description"}, {Label: "Toppings"}},
			Buttons: []Btn{{Label: "CreatePizza", Href: "/pizzas/create_pizza/new", Allowed: true}},
		})
	})

	mux.HandleFunc("GET /pizzas/find", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		item, _ := app.PizzaRepo.Find(id)
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /pizzas/create_pizza", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CreatePizza
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
				http.Error(w, `{"error":"invalid json"}`, 400); return
			}
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Description = r.FormValue("description")
		}
		agg, _, err := cmd.Execute(app.PizzaRepo)
		if err != nil {
			if r.Header.Get("Content-Type") == "application/json" {
				jsonError(w, err); return
			}
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type") == "application/json" {
			w.WriteHeader(201); jsonResponse(w, agg)
		} else {
			http.Redirect(w, r, "/pizzas/show?id=" + agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /pizzas/add_topping", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.AddTopping
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
				http.Error(w, `{"error":"invalid json"}`, 400); return
			}
		} else {
			r.ParseForm()
			cmd.PizzaId = r.FormValue("pizza_id")
			cmd.Name = r.FormValue("name")
			if v := r.FormValue("amount"); v != "" { n, _ := fmt.Sscanf(v, "%d", &cmd.Amount) ; _ = n }
		}
		agg, _, err := cmd.Execute(app.PizzaRepo)
		if err != nil {
			if r.Header.Get("Content-Type") == "application/json" {
				jsonError(w, err); return
			}
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type") == "application/json" {
			w.WriteHeader(201); jsonResponse(w, agg)
		} else {
			http.Redirect(w, r, "/pizzas/show?id=" + agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("GET /orders", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.OrderRepo.All()
			jsonResponse(w, items)
			return
		}
		// HTML index
		type Col struct { Label string }
		type Item struct { ID string; ShortID string; ShowHref string; Cells []string }
		type Btn struct { Label string; Href string; Allowed bool }
		type IndexData struct { AggregateName string; Items []Item; Columns []Col; Buttons []Btn }
		items, _ := app.OrderRepo.All()
		var rows []Item
		for _, obj := range items {
			shortID := obj.ID
			if len(shortID) > 8 { shortID = shortID[:8] + "..." }
			rows = append(rows, Item{ID: obj.ID, ShortID: shortID, ShowHref: "/orders/show?id=" + obj.ID, Cells: []string{fmt.Sprintf("%v", obj.CustomerName), fmt.Sprintf("%d items", len(obj.Items)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Orders", IndexData{
			AggregateName: "Order",
			Items: rows,
			Columns: []Col{{Label: "Customer Name"}, {Label: "Items"}, {Label: "Status"}},
			Buttons: []Btn{{Label: "PlaceOrder", Href: "/orders/place_order/new", Allowed: true}},
		})
	})

	mux.HandleFunc("GET /orders/find", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		item, _ := app.OrderRepo.Find(id)
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /orders/place_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.PlaceOrder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
				http.Error(w, `{"error":"invalid json"}`, 400); return
			}
		} else {
			r.ParseForm()
			cmd.CustomerName = r.FormValue("customer_name")
			cmd.PizzaId = r.FormValue("pizza_id")
			if v := r.FormValue("quantity"); v != "" { n, _ := fmt.Sscanf(v, "%d", &cmd.Quantity) ; _ = n }
		}
		agg, _, err := cmd.Execute(app.OrderRepo)
		if err != nil {
			if r.Header.Get("Content-Type") == "application/json" {
				jsonError(w, err); return
			}
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type") == "application/json" {
			w.WriteHeader(201); jsonResponse(w, agg)
		} else {
			http.Redirect(w, r, "/orders/show?id=" + agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /orders/cancel_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CancelOrder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
				http.Error(w, `{"error":"invalid json"}`, 400); return
			}
		} else {
			r.ParseForm()
			cmd.OrderId = r.FormValue("order_id")
		}
		agg, _, err := cmd.Execute(app.OrderRepo)
		if err != nil {
			if r.Header.Get("Content-Type") == "application/json" {
				jsonError(w, err); return
			}
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type") == "application/json" {
			w.WriteHeader(201); jsonResponse(w, agg)
		} else {
			http.Redirect(w, r, "/orders/show?id=" + agg.ID, http.StatusSeeOther)
		}
	})

	type PizzaField struct { Label string; Value string }
	type PizzaShowItem struct { ID string; Fields []PizzaField }
	type PizzaShowData struct { AggregateName string; BackHref string; Item PizzaShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /pizzas/show", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		obj, _ := app.PizzaRepo.Find(id)
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []PizzaField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Toppings", Value: fmt.Sprintf("%d items", len(obj.Toppings))},
		}
		renderer.Render(w, "show", "Pizza", PizzaShowData{
			AggregateName: "Pizza", BackHref: "/pizzas",
			Item: PizzaShowItem{ID: obj.ID, Fields: fields},
		})
	})

	type OrderField struct { Label string; Value string }
	type OrderShowItem struct { ID string; Fields []OrderField }
	type OrderShowData struct { AggregateName string; BackHref string; Item OrderShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /orders/show", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		obj, _ := app.OrderRepo.Find(id)
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []OrderField{
			{Label: "Customer Name", Value: fmt.Sprintf("%v", obj.CustomerName)},
			{Label: "Items", Value: fmt.Sprintf("%d items", len(obj.Items))},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Order", OrderShowData{
			AggregateName: "Order", BackHref: "/orders",
			Item: OrderShowItem{ID: obj.ID, Fields: fields},
		})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /pizzas/create_pizza/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "CreatePizza", FormData{
			CommandName: "CreatePizza",
			Action: "/pizzas/create_pizza",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /pizzas/add_topping/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "pizza_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "amount", Label: "Amount", InputType: "number", Required: true},
		}
		renderer.Render(w, "form", "AddTopping", FormData{
			CommandName: "AddTopping",
			Action: "/pizzas/add_topping",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /orders/place_order/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "customer_name", Label: "Customer Name", InputType: "text", Required: true},
			// Pizza dropdown built dynamically below
			{Type: "input", Name: "quantity", Label: "Quantity", InputType: "number", Required: true},
		}
		pizzas, _ := app.PizzaRepo.All()
		var pizzaOpts []FormOption
		for _, item := range pizzas {
			pizzaOpts = append(pizzaOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "pizza_id", Label: "Pizza", Required: true, Options: pizzaOpts})
		renderer.Render(w, "form", "PlaceOrder", FormData{
			CommandName: "PlaceOrder",
			Action: "/orders/place_order",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /orders/cancel_order/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "order_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "CancelOrder", FormData{
			CommandName: "CancelOrder",
			Action: "/orders/cancel_order",
			Fields: fields,
		})
	})

	// Config
	type ConfigAgg struct { Name string; Href string; Count int; Commands string; Ports string }
	type ConfigData struct {
		Roles []string; CurrentRole string
		Adapters []string; CurrentAdapter string
		EventCount int; BootedAt string
		Policies []string; Aggregates []ConfigAgg
	}
	currentRole := "admin"
	mux.HandleFunc("GET /config", func(w http.ResponseWriter, r *http.Request) {
		aggs := []ConfigAgg{
			{Name: "Pizza", Href: "/pizzas", Commands: "CreatePizza, AddTopping", Ports: "admin: find, all, create_pizza, add_topping | customer: find, all"},
			{Name: "Order", Href: "/orders", Commands: "PlaceOrder, CancelOrder", Ports: "admin: find, all, place_order, cancel_order | customer: find, all, place_order"},
		}
		pizzaCount, _ := app.PizzaRepo.Count()
		aggs[0].Count = pizzaCount
		orderCount, _ := app.OrderRepo.Count()
		aggs[1].Count = orderCount
		renderer.Render(w, "config", "Config", ConfigData{
			Roles: []string{"admin", "customer"},
			CurrentRole: currentRole,
			Adapters: []string{"memory", "filesystem"},
			CurrentAdapter: "memory",
			EventCount: 0,
			BootedAt: "now",
			Policies: []string{},
			Aggregates: aggs,
		})
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("PizzasDomain on http://localhost%s\n", addr)
	return http.ListenAndServe(addr, mux)
}

func jsonResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}

func jsonError(w http.ResponseWriter, err error) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(422)
	json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
}
