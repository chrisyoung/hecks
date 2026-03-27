package server

import (
	"encoding/json"
	"fmt"
	"net/http"
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

	mux.HandleFunc("GET /pizzas", func(w http.ResponseWriter, r *http.Request) {
		items, _ := app.PizzaRepo.All()
		jsonResponse(w, items)
	})

	mux.HandleFunc("GET /pizzas/find", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		item, _ := app.PizzaRepo.Find(id)
		if item == nil {
			http.Error(w, `{"error":"not found"}`, 404)
			return
		}
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /pizzas/create_pizza", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CreatePizza
		if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
			http.Error(w, `{"error":"invalid json"}`, 400)
			return
		}
		agg, _, err := cmd.Execute(app.PizzaRepo)
		if err != nil {
			jsonError(w, err)
			return
		}
		w.WriteHeader(201)
		jsonResponse(w, agg)
	})

	mux.HandleFunc("POST /pizzas/add_topping", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.AddTopping
		if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
			http.Error(w, `{"error":"invalid json"}`, 400)
			return
		}
		agg, _, err := cmd.Execute(app.PizzaRepo)
		if err != nil {
			jsonError(w, err)
			return
		}
		w.WriteHeader(201)
		jsonResponse(w, agg)
	})

	mux.HandleFunc("GET /orders", func(w http.ResponseWriter, r *http.Request) {
		items, _ := app.OrderRepo.All()
		jsonResponse(w, items)
	})

	mux.HandleFunc("GET /orders/find", func(w http.ResponseWriter, r *http.Request) {
		id := r.URL.Query().Get("id")
		item, _ := app.OrderRepo.Find(id)
		if item == nil {
			http.Error(w, `{"error":"not found"}`, 404)
			return
		}
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /orders/place_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.PlaceOrder
		if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
			http.Error(w, `{"error":"invalid json"}`, 400)
			return
		}
		agg, _, err := cmd.Execute(app.OrderRepo)
		if err != nil {
			jsonError(w, err)
			return
		}
		w.WriteHeader(201)
		jsonResponse(w, agg)
	})

	mux.HandleFunc("POST /orders/cancel_order", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CancelOrder
		if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
			http.Error(w, `{"error":"invalid json"}`, 400)
			return
		}
		agg, _, err := cmd.Execute(app.OrderRepo)
		if err != nil {
			jsonError(w, err)
			return
		}
		w.WriteHeader(201)
		jsonResponse(w, agg)
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("Serving on http://localhost%s\n", addr)
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
