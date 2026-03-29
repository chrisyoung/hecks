package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"os"
	"path/filepath"
	"pizzas_domain/domain"
	"pizzas_domain/adapters/memory"
	"pizzas_domain/runtime"
)

type App struct {
	PizzaRepo domain.PizzaRepository
	OrderRepo domain.OrderRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		PizzaRepo: memory.NewPizzaMemoryRepository(),
		OrderRepo: memory.NewOrderMemoryRepository(),
		EventBus: eventBus,
		CommandBus: runtime.NewCommandBus(eventBus),
	}
}

func (app *App) Start(port int) error {
	mux := http.NewServeMux()

	viewsDir := os.Getenv("VIEWS_DIR")
	if viewsDir == "" {
		exe, _ := os.Executable()
		viewsDir = filepath.Join(filepath.Dir(exe), "..", "views")
		if _, err := os.Stat(viewsDir); err != nil {
			viewsDir = filepath.Join(filepath.Dir(exe), "views")
		}
		if _, err := os.Stat(viewsDir); err != nil { viewsDir = "views" }
	}
	nav := []NavItem{
		{Label: "Pizzas", Href: "/pizzas", Group: ""},
		{Label: "Orders", Href: "/orders", Group: ""},
		{Label: "Config", Href: "/config", Group: "System"},
	}
	renderer := NewRenderer(viewsDir, "Pizzas", nav)

	type HomeAgg struct { Href string; Name string; Commands int; Attributes int; Policies int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "Pizzas", HomeData{
			DomainName: "Pizzas", Aggregates: []HomeAgg{{Name: "Pizzas", Href: "/pizzas", Commands: 2, Attributes: 3, Policies: 0}, {Name: "Orders", Href: "/orders", Commands: 2, Attributes: 3, Policies: 0}},
		})
	})

	type PizzaColumn struct { Label string }
	type PizzaIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type PizzaButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type PizzaIndexData struct { AggregateName string; Description string; Items []PizzaIndexItem; Columns []PizzaColumn; Buttons []PizzaButton; RowActions []RowAction }
	mux.HandleFunc("GET /pizzas", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.PizzaRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.PizzaRepo.All()
		var rows []PizzaIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Add Topping", HrefPrefix: "/pizzas/add_topping/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, PizzaIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/pizzas/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%d items", len(obj.Toppings))}, RowActions: actions})
		}
		renderer.Render(w, "index", "Pizzas", PizzaIndexData{AggregateName: "Pizza", Description: "", Items: rows, Columns: []PizzaColumn{{Label: "Name"}, {Label: "Description"}, {Label: "Toppings"}}, Buttons: []PizzaButton{{Label: "Create Pizza", Href: "/pizzas/create_pizza/new", Allowed: true}}, RowActions: []RowAction{{Label: "Add Topping", HrefPrefix: "/pizzas/add_topping/new?id=", Allowed: true}}})
	})

	mux.HandleFunc("GET /pizzas/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.PizzaRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /pizzas/create_pizza", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CreatePizza
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Description = r.FormValue("description")
		}
		agg, event, err := cmd.Execute(app.PizzaRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/pizzas/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /pizzas/add_topping", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.AddTopping
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.PizzaId = r.FormValue("pizza_id")
			cmd.Name = r.FormValue("name")
			if v := r.FormValue("amount"); v != "" { fmt.Sscanf(v, "%d", &cmd.Amount) }
		}
		agg, event, err := cmd.Execute(app.PizzaRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/pizzas/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type OrderColumn struct { Label string }
	type OrderIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type OrderButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type OrderIndexData struct { AggregateName string; Description string; Items []OrderIndexItem; Columns []OrderColumn; Buttons []OrderButton; RowActions []RowAction }
	mux.HandleFunc("GET /orders", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.OrderRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.OrderRepo.All()
		var rows []OrderIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Cancel Order", HrefPrefix: "/orders/cancel_order", Allowed: true, Direct: true, IdField: "order_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, OrderIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/orders/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.CustomerName), fmt.Sprintf("%d items", len(obj.Items)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Orders", OrderIndexData{AggregateName: "Order", Description: "", Items: rows, Columns: []OrderColumn{{Label: "Customer Name"}, {Label: "Items"}, {Label: "Status"}}, Buttons: []OrderButton{{Label: "Place Order", Href: "/orders/place_order/new", Allowed: true}}, RowActions: []RowAction{{Label: "Cancel Order", HrefPrefix: "/orders/cancel_order", Allowed: true, Direct: true, IdField: "order_id"}}})
	})

	mux.HandleFunc("GET /orders/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.OrderRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /orders/place_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.PlaceOrder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.CustomerName = r.FormValue("customer_name")
			cmd.PizzaId = r.FormValue("pizza_id")
			if v := r.FormValue("quantity"); v != "" { fmt.Sscanf(v, "%d", &cmd.Quantity) }
		}
		agg, event, err := cmd.Execute(app.OrderRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/orders/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /orders/cancel_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CancelOrder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.OrderId = r.FormValue("order_id")
		}
		agg, event, err := cmd.Execute(app.OrderRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/orders/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type PizzaShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type PizzaShowData struct { AggregateName string; Id string; BackHref string; Fields []PizzaShowField; Buttons []PizzaButton }
	mux.HandleFunc("GET /pizzas/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.PizzaRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []PizzaShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Toppings", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Toppings { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
		}
		buttons := []PizzaButton{PizzaButton{Label: "Add Topping", Href: "/pizzas/add_topping/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "Pizza", PizzaShowData{AggregateName: "Pizza", BackHref: "/pizzas", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type OrderShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type OrderShowData struct { AggregateName string; Id string; BackHref string; Fields []OrderShowField; Buttons []OrderButton }
	mux.HandleFunc("GET /orders/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.OrderRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []OrderShowField{
			{Label: "Customer Name", Value: fmt.Sprintf("%v", obj.CustomerName)},
			{Label: "Items", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Items { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Cancel Order → cancelled"}},
		}
		buttons := []OrderButton{OrderButton{Label: "Cancel Order", Href: "/orders/cancel_order", Allowed: true, Direct: true, IdField: "order_id"}}
		renderer.Render(w, "show", "Order", OrderShowData{AggregateName: "Order", BackHref: "/orders", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /pizzas/create_pizza/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "CreatePizza", FormData{
			CommandName: "Create Pizza",
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
			CommandName: "Add Topping",
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
			CommandName: "Place Order",
			Action: "/orders/place_order",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /orders/cancel_order/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "order_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "CancelOrder", FormData{
			CommandName: "Cancel Order",
			Action: "/orders/cancel_order",
			Fields: fields,
		})
	})

	mux.HandleFunc("POST /_reset", func(w http.ResponseWriter, r *http.Request) {
		app.PizzaRepo = memory.NewPizzaMemoryRepository()
		app.OrderRepo = memory.NewOrderMemoryRepository()
		app.EventBus.Clear()
		http.Redirect(w, r, "/config", http.StatusSeeOther)
	})

	mux.HandleFunc("GET /_events", func(w http.ResponseWriter, r *http.Request) {
		events := app.EventBus.Events()
		type eventEntry struct {
			Name string `json:"name"`
			OccurredAt string `json:"occurred_at"`
		}
		var result []eventEntry
		for _, e := range events {
			result = append(result, eventEntry{
				Name: e.EventName(),
				OccurredAt: e.GetOccurredAt().Format(time.RFC3339),
			})
		}
		jsonResponse(w, result)
	})

	mux.HandleFunc("GET /pizzas/queries/by_description", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.PizzaByDescription(app.PizzaRepo, r.URL.Query().Get("desc"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /orders/queries/pending", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.OrderPending(app.OrderRepo)
		jsonResponse(w, results)
	})

	// Config
	type ConfigAgg struct { Name string; Href string; Count int; Commands string; Ports string }
	type ConfigData struct { Roles []string; CurrentRole string; Adapters []string; CurrentAdapter string; EventCount int; BootedAt string; Policies []string; Aggregates []ConfigAgg }
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
			EventCount: len(app.EventBus.Events()),
			BootedAt: "running",
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
