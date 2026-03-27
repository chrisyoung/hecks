package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"operations_domain/domain"
	"operations_domain/adapters/memory"
	"operations_domain/runtime"
)

type App struct {
	DeploymentRepo domain.DeploymentRepository
	IncidentRepo domain.IncidentRepository
	MonitoringRepo domain.MonitoringRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		DeploymentRepo: memory.NewDeploymentMemoryRepository(),
		IncidentRepo: memory.NewIncidentMemoryRepository(),
		MonitoringRepo: memory.NewMonitoringMemoryRepository(),
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
		{Label: "Deployments", Href: "/deployments"},
		{Label: "Incidents", Href: "/incidents"},
		{Label: "Monitorings", Href: "/monitorings"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "OperationsDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "OperationsDomain", HomeData{
			DomainName: "OperationsDomain", Aggregates: []HomeAgg{{Name: "Deployments", Href: "/deployments", Commands: 3, Attributes: 8}, {Name: "Incidents", Href: "/incidents", Commands: 5, Attributes: 10}, {Name: "Monitorings", Href: "/monitorings", Commands: 2, Attributes: 6}},
		})
	})

	type DeploymentCol struct { Label string }
	type DeploymentItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type DeploymentBtn struct { Label string; Href string; Allowed bool }
	type DeploymentIndexData struct { AggregateName string; Items []DeploymentItem; Columns []DeploymentCol; Buttons []DeploymentBtn }
	mux.HandleFunc("GET /deployments", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.DeploymentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.DeploymentRepo.All()
		var rows []DeploymentItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, DeploymentItem{ID: obj.ID, ShortID: sid, ShowHref: "/deployments/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.Environment), fmt.Sprintf("%v", obj.Endpoint), fmt.Sprintf("%v", obj.Purpose), fmt.Sprintf("%v", obj.Audience), fmt.Sprintf("%v", obj.DeployedAt), fmt.Sprintf("%v", obj.DecommissionedAt), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Deployments", DeploymentIndexData{AggregateName: "Deployment", Items: rows, Columns: []DeploymentCol{{Label: "Model Id"}, {Label: "Environment"}, {Label: "Endpoint"}, {Label: "Purpose"}, {Label: "Audience"}, {Label: "Deployed At"}, {Label: "Decommissioned At"}, {Label: "Status"}}, Buttons: []DeploymentBtn{{Label: "PlanDeployment", Href: "/deployments/plan_deployment/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /deployments/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.DeploymentRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /deployments/plan_deployment", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.PlanDeployment
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.Environment = r.FormValue("environment")
			cmd.Endpoint = r.FormValue("endpoint")
			cmd.Purpose = r.FormValue("purpose")
			cmd.Audience = r.FormValue("audience")
		}
		agg, event, err := cmd.Execute(app.DeploymentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/deployments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /deployments/deploy_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.DeployModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.DeploymentId = r.FormValue("deployment_id")
		}
		agg, event, err := cmd.Execute(app.DeploymentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/deployments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /deployments/decommission_deployment", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.DecommissionDeployment
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.DeploymentId = r.FormValue("deployment_id")
		}
		agg, event, err := cmd.Execute(app.DeploymentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/deployments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type IncidentCol struct { Label string }
	type IncidentItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type IncidentBtn struct { Label string; Href string; Allowed bool }
	type IncidentIndexData struct { AggregateName string; Items []IncidentItem; Columns []IncidentCol; Buttons []IncidentBtn }
	mux.HandleFunc("GET /incidents", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.IncidentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.IncidentRepo.All()
		var rows []IncidentItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, IncidentItem{ID: obj.ID, ShortID: sid, ShowHref: "/incidents/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.Severity), fmt.Sprintf("%v", obj.Category), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.ReportedById), fmt.Sprintf("%v", obj.ReportedAt), fmt.Sprintf("%v", obj.ResolvedAt), fmt.Sprintf("%v", obj.Resolution), fmt.Sprintf("%v", obj.RootCause), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Incidents", IncidentIndexData{AggregateName: "Incident", Items: rows, Columns: []IncidentCol{{Label: "Model Id"}, {Label: "Severity"}, {Label: "Category"}, {Label: "Description"}, {Label: "Reported By Id"}, {Label: "Reported At"}, {Label: "Resolved At"}, {Label: "Resolution"}, {Label: "Root Cause"}, {Label: "Status"}}, Buttons: []IncidentBtn{{Label: "ReportIncident", Href: "/incidents/report_incident/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /incidents/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.IncidentRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /incidents/report_incident", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ReportIncident
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.Severity = r.FormValue("severity")
			cmd.Category = r.FormValue("category")
			cmd.Description = r.FormValue("description")
			cmd.ReportedById = r.FormValue("reported_by_id")
		}
		agg, event, err := cmd.Execute(app.IncidentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/incidents/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /incidents/investigate_incident", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.InvestigateIncident
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.IncidentId = r.FormValue("incident_id")
		}
		agg, event, err := cmd.Execute(app.IncidentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/incidents/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /incidents/mitigate_incident", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.MitigateIncident
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.IncidentId = r.FormValue("incident_id")
		}
		agg, event, err := cmd.Execute(app.IncidentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/incidents/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /incidents/resolve_incident", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ResolveIncident
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.IncidentId = r.FormValue("incident_id")
			cmd.Resolution = r.FormValue("resolution")
			cmd.RootCause = r.FormValue("root_cause")
		}
		agg, event, err := cmd.Execute(app.IncidentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/incidents/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /incidents/close_incident", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CloseIncident
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.IncidentId = r.FormValue("incident_id")
		}
		agg, event, err := cmd.Execute(app.IncidentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/incidents/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type MonitoringCol struct { Label string }
	type MonitoringItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type MonitoringBtn struct { Label string; Href string; Allowed bool }
	type MonitoringIndexData struct { AggregateName string; Items []MonitoringItem; Columns []MonitoringCol; Buttons []MonitoringBtn }
	mux.HandleFunc("GET /monitorings", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.MonitoringRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.MonitoringRepo.All()
		var rows []MonitoringItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, MonitoringItem{ID: obj.ID, ShortID: sid, ShowHref: "/monitorings/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.DeploymentId), fmt.Sprintf("%v", obj.MetricName), fmt.Sprintf("%v", obj.Value), fmt.Sprintf("%v", obj.Threshold), fmt.Sprintf("%v", obj.RecordedAt)}})
		}
		renderer.Render(w, "index", "Monitorings", MonitoringIndexData{AggregateName: "Monitoring", Items: rows, Columns: []MonitoringCol{{Label: "Model Id"}, {Label: "Deployment Id"}, {Label: "Metric Name"}, {Label: "Value"}, {Label: "Threshold"}, {Label: "Recorded At"}}, Buttons: []MonitoringBtn{{Label: "RecordMetric", Href: "/monitorings/record_metric/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /monitorings/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.MonitoringRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /monitorings/record_metric", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RecordMetric
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.DeploymentId = r.FormValue("deployment_id")
			cmd.MetricName = r.FormValue("metric_name")
			if v := r.FormValue("value"); v != "" { fmt.Sscanf(v, "%f", &cmd.Value) }
			if v := r.FormValue("threshold"); v != "" { fmt.Sscanf(v, "%f", &cmd.Threshold) }
		}
		agg, event, err := cmd.Execute(app.MonitoringRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/monitorings/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /monitorings/set_threshold", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.SetThreshold
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.MonitoringId = r.FormValue("monitoring_id")
			if v := r.FormValue("threshold"); v != "" { fmt.Sscanf(v, "%f", &cmd.Threshold) }
		}
		agg, event, err := cmd.Execute(app.MonitoringRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/monitorings/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type DeploymentField struct { Label string; Value string }
	type DeploymentShowItem struct { ID string; Fields []DeploymentField }
	type DeploymentShowData struct { AggregateName string; BackHref string; Item DeploymentShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /deployments/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DeploymentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []DeploymentField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Environment", Value: fmt.Sprintf("%v", obj.Environment)},
			{Label: "Endpoint", Value: fmt.Sprintf("%v", obj.Endpoint)},
			{Label: "Purpose", Value: fmt.Sprintf("%v", obj.Purpose)},
			{Label: "Audience", Value: fmt.Sprintf("%v", obj.Audience)},
			{Label: "Deployed At", Value: fmt.Sprintf("%v", obj.DeployedAt)},
			{Label: "Decommissioned At", Value: fmt.Sprintf("%v", obj.DecommissionedAt)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Deployment", DeploymentShowData{AggregateName: "Deployment", BackHref: "/deployments", Item: DeploymentShowItem{ID: obj.ID, Fields: fields}})
	})

	type IncidentField struct { Label string; Value string }
	type IncidentShowItem struct { ID string; Fields []IncidentField }
	type IncidentShowData struct { AggregateName string; BackHref string; Item IncidentShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /incidents/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.IncidentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []IncidentField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Severity", Value: fmt.Sprintf("%v", obj.Severity)},
			{Label: "Category", Value: fmt.Sprintf("%v", obj.Category)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Reported By Id", Value: fmt.Sprintf("%v", obj.ReportedById)},
			{Label: "Reported At", Value: fmt.Sprintf("%v", obj.ReportedAt)},
			{Label: "Resolved At", Value: fmt.Sprintf("%v", obj.ResolvedAt)},
			{Label: "Resolution", Value: fmt.Sprintf("%v", obj.Resolution)},
			{Label: "Root Cause", Value: fmt.Sprintf("%v", obj.RootCause)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Incident", IncidentShowData{AggregateName: "Incident", BackHref: "/incidents", Item: IncidentShowItem{ID: obj.ID, Fields: fields}})
	})

	type MonitoringField struct { Label string; Value string }
	type MonitoringShowItem struct { ID string; Fields []MonitoringField }
	type MonitoringShowData struct { AggregateName string; BackHref string; Item MonitoringShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /monitorings/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.MonitoringRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []MonitoringField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Deployment Id", Value: fmt.Sprintf("%v", obj.DeploymentId)},
			{Label: "Metric Name", Value: fmt.Sprintf("%v", obj.MetricName)},
			{Label: "Value", Value: fmt.Sprintf("%v", obj.Value)},
			{Label: "Threshold", Value: fmt.Sprintf("%v", obj.Threshold)},
			{Label: "Recorded At", Value: fmt.Sprintf("%v", obj.RecordedAt)},
		}
		renderer.Render(w, "show", "Monitoring", MonitoringShowData{AggregateName: "Monitoring", BackHref: "/monitorings", Item: MonitoringShowItem{ID: obj.ID, Fields: fields}})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /deployments/plan_deployment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "environment", Label: "Environment", InputType: "text", Required: true},
			{Type: "input", Name: "endpoint", Label: "Endpoint", InputType: "text", Required: true},
			{Type: "input", Name: "purpose", Label: "Purpose", InputType: "text", Required: true},
			{Type: "input", Name: "audience", Label: "Audience", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "PlanDeployment", FormData{
			CommandName: "PlanDeployment",
			Action: "/deployments/plan_deployment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /deployments/deploy_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "deployment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DeployModel", FormData{
			CommandName: "DeployModel",
			Action: "/deployments/deploy_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /deployments/decommission_deployment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "deployment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DecommissionDeployment", FormData{
			CommandName: "DecommissionDeployment",
			Action: "/deployments/decommission_deployment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/report_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "severity", Label: "Severity", InputType: "text", Required: true},
			{Type: "input", Name: "category", Label: "Category", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ReportIncident", FormData{
			CommandName: "ReportIncident",
			Action: "/incidents/report_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/investigate_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "InvestigateIncident", FormData{
			CommandName: "InvestigateIncident",
			Action: "/incidents/investigate_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/mitigate_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "MitigateIncident", FormData{
			CommandName: "MitigateIncident",
			Action: "/incidents/mitigate_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/resolve_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "resolution", Label: "Resolution", InputType: "text", Required: true},
			{Type: "input", Name: "root_cause", Label: "Root Cause", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ResolveIncident", FormData{
			CommandName: "ResolveIncident",
			Action: "/incidents/resolve_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/close_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "CloseIncident", FormData{
			CommandName: "CloseIncident",
			Action: "/incidents/close_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /monitorings/record_metric/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// Deployment dropdown built dynamically below
			{Type: "input", Name: "metric_name", Label: "Metric Name", InputType: "text", Required: true},
			{Type: "input", Name: "value", Label: "Value", InputType: "number", Required: true},
			{Type: "input", Name: "threshold", Label: "Threshold", InputType: "number", Required: true},
		}
		deployments, _ := app.DeploymentRepo.All()
		var deploymentOpts []FormOption
		for _, item := range deployments {
			deploymentOpts = append(deploymentOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.ID), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "deployment_id", Label: "Deployment", Required: true, Options: deploymentOpts})
		renderer.Render(w, "form", "RecordMetric", FormData{
			CommandName: "RecordMetric",
			Action: "/monitorings/record_metric",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /monitorings/set_threshold/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "monitoring_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "threshold", Label: "Threshold", InputType: "number", Required: true},
		}
		renderer.Render(w, "form", "SetThreshold", FormData{
			CommandName: "SetThreshold",
			Action: "/monitorings/set_threshold",
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
			{Name: "Deployment", Href: "/deployments", Commands: "PlanDeployment, DeployModel, DecommissionDeployment", Ports: "(none)"},
			{Name: "Incident", Href: "/incidents", Commands: "ReportIncident, InvestigateIncident, MitigateIncident, ResolveIncident, CloseIncident", Ports: "(none)"},
			{Name: "Monitoring", Href: "/monitorings", Commands: "RecordMetric, SetThreshold", Ports: "(none)"},
		}
		deploymentCount, _ := app.DeploymentRepo.Count()
		aggs[0].Count = deploymentCount
		incidentCount, _ := app.IncidentRepo.Count()
		aggs[1].Count = incidentCount
		monitoringCount, _ := app.MonitoringRepo.Count()
		aggs[2].Count = monitoringCount
		renderer.Render(w, "config", "Config", ConfigData{
			Roles: []string{"admin"},
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
	fmt.Printf("OperationsDomain on http://localhost%s\n", addr)
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
