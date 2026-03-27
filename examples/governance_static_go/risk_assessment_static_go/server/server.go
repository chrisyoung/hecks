package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"risk_assessment_domain/domain"
	"risk_assessment_domain/adapters/memory"
	"risk_assessment_domain/runtime"
)

type App struct {
	AssessmentRepo domain.AssessmentRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		AssessmentRepo: memory.NewAssessmentMemoryRepository(),
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
		{Label: "Assessments", Href: "/assessments"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "RiskAssessmentDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "RiskAssessmentDomain", HomeData{
			DomainName: "RiskAssessmentDomain", Aggregates: []HomeAgg{{Name: "Assessments", Href: "/assessments", Commands: 4, Attributes: 11}},
		})
	})

	type AssessmentCol struct { Label string }
	type AssessmentItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type AssessmentBtn struct { Label string; Href string; Allowed bool }
	type AssessmentIndexData struct { AggregateName string; Items []AssessmentItem; Columns []AssessmentCol; Buttons []AssessmentBtn }
	mux.HandleFunc("GET /assessments", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AssessmentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AssessmentRepo.All()
		var rows []AssessmentItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, AssessmentItem{ID: obj.ID, ShortID: sid, ShowHref: "/assessments/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.AssessorId), fmt.Sprintf("%v", obj.RiskLevel), fmt.Sprintf("%v", obj.BiasScore), fmt.Sprintf("%v", obj.SafetyScore), fmt.Sprintf("%v", obj.TransparencyScore), fmt.Sprintf("%v", obj.OverallScore), fmt.Sprintf("%v", obj.SubmittedAt), fmt.Sprintf("%d items", len(obj.Findings)), fmt.Sprintf("%d items", len(obj.Mitigations)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Assessments", AssessmentIndexData{AggregateName: "Assessment", Items: rows, Columns: []AssessmentCol{{Label: "Model Id"}, {Label: "Assessor Id"}, {Label: "Risk Level"}, {Label: "Bias Score"}, {Label: "Safety Score"}, {Label: "Transparency Score"}, {Label: "Overall Score"}, {Label: "Submitted At"}, {Label: "Findings"}, {Label: "Mitigations"}, {Label: "Status"}}, Buttons: []AssessmentBtn{{Label: "InitiateAssessment", Href: "/assessments/initiate_assessment/new", Allowed: true}}})
	})

	mux.HandleFunc("GET /assessments/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.AssessmentRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /assessments/initiate_assessment", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.InitiateAssessment
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.AssessorId = r.FormValue("assessor_id")
		}
		agg, event, err := cmd.Execute(app.AssessmentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/assessments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /assessments/record_finding", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RecordFinding
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AssessmentId = r.FormValue("assessment_id")
			cmd.Category = r.FormValue("category")
			cmd.Severity = r.FormValue("severity")
			cmd.Description = r.FormValue("description")
		}
		agg, event, err := cmd.Execute(app.AssessmentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/assessments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /assessments/submit_assessment", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.SubmitAssessment
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AssessmentId = r.FormValue("assessment_id")
			cmd.RiskLevel = r.FormValue("risk_level")
			if v := r.FormValue("bias_score"); v != "" { fmt.Sscanf(v, "%f", &cmd.BiasScore) }
			if v := r.FormValue("safety_score"); v != "" { fmt.Sscanf(v, "%f", &cmd.SafetyScore) }
			if v := r.FormValue("transparency_score"); v != "" { fmt.Sscanf(v, "%f", &cmd.TransparencyScore) }
			if v := r.FormValue("overall_score"); v != "" { fmt.Sscanf(v, "%f", &cmd.OverallScore) }
		}
		agg, event, err := cmd.Execute(app.AssessmentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/assessments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /assessments/reject_assessment", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RejectAssessment
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AssessmentId = r.FormValue("assessment_id")
		}
		agg, event, err := cmd.Execute(app.AssessmentRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/assessments/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type AssessmentField struct { Label string; Value string }
	type AssessmentShowItem struct { ID string; Fields []AssessmentField }
	type AssessmentShowData struct { AggregateName string; BackHref string; Item AssessmentShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /assessments/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AssessmentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AssessmentField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Assessor Id", Value: fmt.Sprintf("%v", obj.AssessorId)},
			{Label: "Risk Level", Value: fmt.Sprintf("%v", obj.RiskLevel)},
			{Label: "Bias Score", Value: fmt.Sprintf("%v", obj.BiasScore)},
			{Label: "Safety Score", Value: fmt.Sprintf("%v", obj.SafetyScore)},
			{Label: "Transparency Score", Value: fmt.Sprintf("%v", obj.TransparencyScore)},
			{Label: "Overall Score", Value: fmt.Sprintf("%v", obj.OverallScore)},
			{Label: "Submitted At", Value: fmt.Sprintf("%v", obj.SubmittedAt)},
			{Label: "Findings", Value: fmt.Sprintf("%v", obj.Findings)},
			{Label: "Mitigations", Value: fmt.Sprintf("%v", obj.Mitigations)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Assessment", AssessmentShowData{AggregateName: "Assessment", BackHref: "/assessments", Item: AssessmentShowItem{ID: obj.ID, Fields: fields}})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /assessments/initiate_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "InitiateAssessment", FormData{
			CommandName: "InitiateAssessment",
			Action: "/assessments/initiate_assessment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/record_finding/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "assessment_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "category", Label: "Category", InputType: "text", Required: true},
			{Type: "input", Name: "severity", Label: "Severity", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RecordFinding", FormData{
			CommandName: "RecordFinding",
			Action: "/assessments/record_finding",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/submit_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "assessment_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "risk_level", Label: "Risk Level", InputType: "text", Required: true},
			{Type: "input", Name: "bias_score", Label: "Bias Score", InputType: "number", Required: true},
			{Type: "input", Name: "safety_score", Label: "Safety Score", InputType: "number", Required: true},
			{Type: "input", Name: "transparency_score", Label: "Transparency Score", InputType: "number", Required: true},
			{Type: "input", Name: "overall_score", Label: "Overall Score", InputType: "number", Required: true},
		}
		renderer.Render(w, "form", "SubmitAssessment", FormData{
			CommandName: "SubmitAssessment",
			Action: "/assessments/submit_assessment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/reject_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "assessment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RejectAssessment", FormData{
			CommandName: "RejectAssessment",
			Action: "/assessments/reject_assessment",
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
			{Name: "Assessment", Href: "/assessments", Commands: "InitiateAssessment, RecordFinding, SubmitAssessment, RejectAssessment", Ports: "(none)"},
		}
		assessmentCount, _ := app.AssessmentRepo.Count()
		aggs[0].Count = assessmentCount
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
	fmt.Printf("RiskAssessmentDomain on http://localhost%s\n", addr)
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
