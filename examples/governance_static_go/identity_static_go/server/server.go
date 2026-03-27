package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"identity_domain/domain"
	"identity_domain/adapters/memory"
	"identity_domain/runtime"
)

type App struct {
	StakeholderRepo domain.StakeholderRepository
	AuditLogRepo domain.AuditLogRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		StakeholderRepo: memory.NewStakeholderMemoryRepository(),
		AuditLogRepo: memory.NewAuditLogMemoryRepository(),
		EventBus: eventBus,
		CommandBus: runtime.NewCommandBus(eventBus),
	}
}

func (app *App) Start(port int) error {
	mux := http.NewServeMux()

	exe, _ := os.Executable()
	viewsDir := filepath.Join(filepath.Dir(exe), "..", "views")
	if _, err := os.Stat(viewsDir); err != nil { viewsDir = "views" }
	nav := []NavItem{
		{Label: "Home", Href: "/"},
		{Label: "Stakeholders", Href: "/stakeholders"},
		{Label: "AuditLogs", Href: "/audit_logs"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "IdentityDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "IdentityDomain", HomeData{
			DomainName: "IdentityDomain", Aggregates: []HomeAgg{{Name: "Stakeholders", Href: "/stakeholders", Commands: 3, Attributes: 5}, {Name: "AuditLogs", Href: "/audit_logs", Commands: 1, Attributes: 6}},
		})
	})

	type StakeholderCol struct { Label string }
	type StakeholderItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type StakeholderBtn struct { Label string; Href string; Allowed bool }
	type StakeholderIndexData struct { AggregateName string; Items []StakeholderItem; Columns []StakeholderCol; Buttons []StakeholderBtn }
	mux.HandleFunc("GET /stakeholders", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.StakeholderRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.StakeholderRepo.All()
		var rows []StakeholderItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, StakeholderItem{ID: obj.ID, ShortID: sid, ShowHref: "/stakeholders/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Email), fmt.Sprintf("%v", obj.Role), fmt.Sprintf("%v", obj.Team), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Stakeholders", StakeholderIndexData{AggregateName: "Stakeholder", Items: rows, Columns: []StakeholderCol{{Label: "Name"}, {Label: "Email"}, {Label: "Role"}, {Label: "Team"}, {Label: "Status"}}, Buttons: []StakeholderBtn{{Label: "RegisterStakeholder", Href: "/stakeholders/register_stakeholder/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /stakeholders/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.StakeholderRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /stakeholders/register_stakeholder", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RegisterStakeholder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Email = r.FormValue("email")
			cmd.Role = r.FormValue("role")
			cmd.Team = r.FormValue("team")
		}
		agg, event, err := cmd.Execute(app.StakeholderRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/stakeholders/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /stakeholders/assign_role", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.AssignRole
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.StakeholderId = r.FormValue("stakeholder_id")
			cmd.Role = r.FormValue("role")
		}
		agg, event, err := cmd.Execute(app.StakeholderRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/stakeholders/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /stakeholders/deactivate_stakeholder", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.DeactivateStakeholder
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.StakeholderId = r.FormValue("stakeholder_id")
		}
		agg, event, err := cmd.Execute(app.StakeholderRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/stakeholders/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type AuditLogCol struct { Label string }
	type AuditLogItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type AuditLogBtn struct { Label string; Href string; Allowed bool }
	type AuditLogIndexData struct { AggregateName string; Items []AuditLogItem; Columns []AuditLogCol; Buttons []AuditLogBtn }
	mux.HandleFunc("GET /audit_logs", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AuditLogRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AuditLogRepo.All()
		var rows []AuditLogItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, AuditLogItem{ID: obj.ID, ShortID: sid, ShowHref: "/audit_logs/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.EntityType), fmt.Sprintf("%v", obj.EntityId), fmt.Sprintf("%v", obj.Action), fmt.Sprintf("%v", obj.ActorId), fmt.Sprintf("%v", obj.Details), fmt.Sprintf("%v", obj.Timestamp)}})
		}
		renderer.Render(w, "index", "AuditLogs", AuditLogIndexData{AggregateName: "AuditLog", Items: rows, Columns: []AuditLogCol{{Label: "Entity Type"}, {Label: "Entity Id"}, {Label: "Action"}, {Label: "Actor Id"}, {Label: "Details"}, {Label: "Timestamp"}}, Buttons: []AuditLogBtn{{Label: "RecordEntry", Href: "/audit_logs/record_entry/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /audit_logs/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.AuditLogRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /audit_logs/record_entry", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RecordEntry
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.EntityType = r.FormValue("entity_type")
			cmd.EntityId = r.FormValue("entity_id")
			cmd.Action = r.FormValue("action")
			cmd.ActorId = r.FormValue("actor_id")
			cmd.Details = r.FormValue("details")
		}
		agg, event, err := cmd.Execute(app.AuditLogRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/audit_logs/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type StakeholderField struct { Label string; Value string }
	type StakeholderShowItem struct { ID string; Fields []StakeholderField }
	type StakeholderShowData struct { AggregateName string; BackHref string; Item StakeholderShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /stakeholders/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.StakeholderRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []StakeholderField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Email", Value: fmt.Sprintf("%v", obj.Email)},
			{Label: "Role", Value: fmt.Sprintf("%v", obj.Role)},
			{Label: "Team", Value: fmt.Sprintf("%v", obj.Team)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Stakeholder", StakeholderShowData{AggregateName: "Stakeholder", BackHref: "/stakeholders", Item: StakeholderShowItem{ID: obj.ID, Fields: fields}})
	})

	type AuditLogField struct { Label string; Value string }
	type AuditLogShowItem struct { ID string; Fields []AuditLogField }
	type AuditLogShowData struct { AggregateName string; BackHref string; Item AuditLogShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /audit_logs/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AuditLogRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AuditLogField{
			{Label: "Entity Type", Value: fmt.Sprintf("%v", obj.EntityType)},
			{Label: "Entity Id", Value: fmt.Sprintf("%v", obj.EntityId)},
			{Label: "Action", Value: fmt.Sprintf("%v", obj.Action)},
			{Label: "Actor Id", Value: fmt.Sprintf("%v", obj.ActorId)},
			{Label: "Details", Value: fmt.Sprintf("%v", obj.Details)},
			{Label: "Timestamp", Value: fmt.Sprintf("%v", obj.Timestamp)},
		}
		renderer.Render(w, "show", "AuditLog", AuditLogShowData{AggregateName: "AuditLog", BackHref: "/audit_logs", Item: AuditLogShowItem{ID: obj.ID, Fields: fields}})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /stakeholders/register_stakeholder/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "email", Label: "Email", InputType: "text", Required: true},
			{Type: "input", Name: "role", Label: "Role", InputType: "text", Required: true},
			{Type: "input", Name: "team", Label: "Team", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RegisterStakeholder", FormData{
			CommandName: "RegisterStakeholder",
			Action: "/stakeholders/register_stakeholder",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /stakeholders/assign_role/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "stakeholder_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "role", Label: "Role", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "AssignRole", FormData{
			CommandName: "AssignRole",
			Action: "/stakeholders/assign_role",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /stakeholders/deactivate_stakeholder/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "stakeholder_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DeactivateStakeholder", FormData{
			CommandName: "DeactivateStakeholder",
			Action: "/stakeholders/deactivate_stakeholder",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /audit_logs/record_entry/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "entity_type", Label: "Entity Type", InputType: "text", Required: true},
			{Type: "input", Name: "action", Label: "Action", InputType: "text", Required: true},
			{Type: "input", Name: "details", Label: "Details", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RecordEntry", FormData{
			CommandName: "RecordEntry",
			Action: "/audit_logs/record_entry",
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
			{Name: "Stakeholder", Href: "/stakeholders", Commands: "RegisterStakeholder, AssignRole, DeactivateStakeholder", Ports: "(none)"},
			{Name: "AuditLog", Href: "/audit_logs", Commands: "RecordEntry", Ports: "(none)"},
		}
		stakeholderCount, _ := app.StakeholderRepo.Count()
		aggs[0].Count = stakeholderCount
		auditlogCount, _ := app.AuditLogRepo.Count()
		aggs[1].Count = auditlogCount
		renderer.Render(w, "config", "Config", ConfigData{
			Roles: []string{"admin"},
			CurrentRole: currentRole,
			Adapters: []string{"memory", "filesystem"},
			CurrentAdapter: "memory",
			EventCount: len(app.EventBus.Events()),
			BootedAt: "running",
			Policies: []string{"RegisteredModel → AuditModelRegistration", "SuspendedModel → AuditModelSuspension", "ReportedIncident → AuditIncidentReport"},
			Aggregates: aggs,
		})
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("IdentityDomain on http://localhost%s\n", addr)
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
