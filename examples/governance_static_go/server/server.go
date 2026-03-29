package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"os"
	"path/filepath"
	"governance_domain/domain"
	"governance_domain/adapters/memory"
	"governance_domain/runtime"
)

type App struct {
	GovernancePolicyRepo domain.GovernancePolicyRepository
	RegulatoryFrameworkRepo domain.RegulatoryFrameworkRepository
	ComplianceReviewRepo domain.ComplianceReviewRepository
	ExemptionRepo domain.ExemptionRepository
	TrainingRecordRepo domain.TrainingRecordRepository
	StakeholderRepo domain.StakeholderRepository
	AuditLogRepo domain.AuditLogRepository
	AiModelRepo domain.AiModelRepository
	VendorRepo domain.VendorRepository
	DataUsageAgreementRepo domain.DataUsageAgreementRepository
	DeploymentRepo domain.DeploymentRepository
	IncidentRepo domain.IncidentRepository
	MonitoringRepo domain.MonitoringRepository
	AssessmentRepo domain.AssessmentRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
	ViewStates map[string]map[string]interface{}
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		GovernancePolicyRepo: memory.NewGovernancePolicyMemoryRepository(),
		RegulatoryFrameworkRepo: memory.NewRegulatoryFrameworkMemoryRepository(),
		ComplianceReviewRepo: memory.NewComplianceReviewMemoryRepository(),
		ExemptionRepo: memory.NewExemptionMemoryRepository(),
		TrainingRecordRepo: memory.NewTrainingRecordMemoryRepository(),
		StakeholderRepo: memory.NewStakeholderMemoryRepository(),
		AuditLogRepo: memory.NewAuditLogMemoryRepository(),
		AiModelRepo: memory.NewAiModelMemoryRepository(),
		VendorRepo: memory.NewVendorMemoryRepository(),
		DataUsageAgreementRepo: memory.NewDataUsageAgreementMemoryRepository(),
		DeploymentRepo: memory.NewDeploymentMemoryRepository(),
		IncidentRepo: memory.NewIncidentMemoryRepository(),
		MonitoringRepo: memory.NewMonitoringMemoryRepository(),
		AssessmentRepo: memory.NewAssessmentMemoryRepository(),
		EventBus: eventBus,
		CommandBus: runtime.NewCommandBus(eventBus),
		ViewStates: map[string]map[string]interface{}{"ModelDashboard": {}},
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
		{Label: "Governance Policies", Href: "/governance_policys", Group: "Compliance"},
		{Label: "Regulatory Frameworks", Href: "/regulatory_frameworks", Group: "Compliance"},
		{Label: "Compliance Reviews", Href: "/compliance_reviews", Group: "Compliance"},
		{Label: "Exemptions", Href: "/exemptions", Group: "Compliance"},
		{Label: "Training Records", Href: "/training_records", Group: "Compliance"},
		{Label: "Stakeholders", Href: "/stakeholders", Group: "Identity"},
		{Label: "Audit Logs", Href: "/audit_logs", Group: "Identity"},
		{Label: "Ai Models", Href: "/ai_models", Group: "Model Registry"},
		{Label: "Vendors", Href: "/vendors", Group: "Model Registry"},
		{Label: "Data Usage Agreements", Href: "/data_usage_agreements", Group: "Model Registry"},
		{Label: "Deployments", Href: "/deployments", Group: "Operations"},
		{Label: "Incidents", Href: "/incidents", Group: "Operations"},
		{Label: "Monitorings", Href: "/monitorings", Group: "Operations"},
		{Label: "Assessments", Href: "/assessments", Group: "Risk Assessment"},
		{Label: "Config", Href: "/config", Group: "System"},
	}
	renderer := NewRenderer(viewsDir, "Governance", nav)

	type HomeAgg struct { Href string; Name string; Commands int; Attributes int; Policies int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "Governance", HomeData{
			DomainName: "Governance", Aggregates: []HomeAgg{{Name: "Governance Policies", Href: "/governance_policys", Commands: 5, Attributes: 8, Policies: 0}, {Name: "Regulatory Frameworks", Href: "/regulatory_frameworks", Commands: 3, Attributes: 7, Policies: 0}, {Name: "Compliance Reviews", Href: "/compliance_reviews", Commands: 4, Attributes: 8, Policies: 0}, {Name: "Exemptions", Href: "/exemptions", Commands: 3, Attributes: 9, Policies: 0}, {Name: "Training Records", Href: "/training_records", Commands: 3, Attributes: 6, Policies: 0}, {Name: "Stakeholders", Href: "/stakeholders", Commands: 3, Attributes: 5, Policies: 0}, {Name: "Audit Logs", Href: "/audit_logs", Commands: 1, Attributes: 6, Policies: 3}, {Name: "Ai Models", Href: "/ai_models", Commands: 6, Attributes: 11, Policies: 3}, {Name: "Vendors", Href: "/vendors", Commands: 3, Attributes: 7, Policies: 0}, {Name: "Data Usage Agreements", Href: "/data_usage_agreements", Commands: 4, Attributes: 8, Policies: 0}, {Name: "Deployments", Href: "/deployments", Commands: 3, Attributes: 8, Policies: 0}, {Name: "Incidents", Href: "/incidents", Commands: 5, Attributes: 10, Policies: 0}, {Name: "Monitorings", Href: "/monitorings", Commands: 2, Attributes: 6, Policies: 0}, {Name: "Assessments", Href: "/assessments", Commands: 4, Attributes: 11, Policies: 0}},
		})
	})

	type GovernancePolicyColumn struct { Label string }
	type GovernancePolicyIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type GovernancePolicyButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type GovernancePolicyIndexData struct { AggregateName string; Description string; Items []GovernancePolicyIndexItem; Columns []GovernancePolicyColumn; Buttons []GovernancePolicyButton; RowActions []RowAction }
	mux.HandleFunc("GET /governance_policys", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.GovernancePolicyRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.GovernancePolicyRepo.All()
		var rows []GovernancePolicyIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Activate Policy", HrefPrefix: "/governance_policys/activate_policy/new?id=", Allowed: true}, {Label: "Suspend Policy", HrefPrefix: "/governance_policys/suspend_policy", Allowed: true, Direct: true, IdField: "policy_id"}, {Label: "Retire Policy", HrefPrefix: "/governance_policys/retire_policy", Allowed: true, Direct: true, IdField: "policy_id"}, {Label: "Update Review Date", HrefPrefix: "/governance_policys/update_review_date/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, GovernancePolicyIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/governance_policys/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.Category), fmt.Sprintf("%v", obj.FrameworkId), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.ReviewDate), fmt.Sprintf("%d items", len(obj.Requirements)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "GovernancePolicys", GovernancePolicyIndexData{AggregateName: "GovernancePolicy", Description: "Organizational policies governing AI model usage and compliance", Items: rows, Columns: []GovernancePolicyColumn{{Label: "Name"}, {Label: "Description"}, {Label: "Category"}, {Label: "Framework Id"}, {Label: "Effective Date"}, {Label: "Review Date"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []GovernancePolicyButton{{Label: "Create Policy", Href: "/governance_policys/create_policy/new", Allowed: true}}, RowActions: []RowAction{{Label: "Activate Policy", HrefPrefix: "/governance_policys/activate_policy/new?id=", Allowed: true}, {Label: "Suspend Policy", HrefPrefix: "/governance_policys/suspend_policy", Allowed: true, Direct: true, IdField: "policy_id"}, {Label: "Retire Policy", HrefPrefix: "/governance_policys/retire_policy", Allowed: true, Direct: true, IdField: "policy_id"}, {Label: "Update Review Date", HrefPrefix: "/governance_policys/update_review_date/new?id=", Allowed: true}}})
	})

	mux.HandleFunc("GET /governance_policys/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.GovernancePolicyRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /governance_policys/create_policy", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CreatePolicy
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Description = r.FormValue("description")
			cmd.Category = r.FormValue("category")
			cmd.FrameworkId = r.FormValue("framework_id")
		}
		agg, event, err := cmd.Execute(app.GovernancePolicyRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/governance_policys/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /governance_policys/activate_policy", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ActivatePolicy
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.PolicyId = r.FormValue("policy_id")
			if v := r.FormValue("effective_date"); v != "" { cmd.EffectiveDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.GovernancePolicyRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/governance_policys/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /governance_policys/suspend_policy", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.SuspendPolicy
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.PolicyId = r.FormValue("policy_id")
		}
		agg, event, err := cmd.Execute(app.GovernancePolicyRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/governance_policys/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /governance_policys/retire_policy", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RetirePolicy
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.PolicyId = r.FormValue("policy_id")
		}
		agg, event, err := cmd.Execute(app.GovernancePolicyRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/governance_policys/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /governance_policys/update_review_date", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.UpdateReviewDate
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.PolicyId = r.FormValue("policy_id")
			if v := r.FormValue("review_date"); v != "" { cmd.ReviewDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.GovernancePolicyRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/governance_policys/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type RegulatoryFrameworkColumn struct { Label string }
	type RegulatoryFrameworkIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type RegulatoryFrameworkButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type RegulatoryFrameworkIndexData struct { AggregateName string; Description string; Items []RegulatoryFrameworkIndexItem; Columns []RegulatoryFrameworkColumn; Buttons []RegulatoryFrameworkButton; RowActions []RowAction }
	mux.HandleFunc("GET /regulatory_frameworks", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.RegulatoryFrameworkRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.RegulatoryFrameworkRepo.All()
		var rows []RegulatoryFrameworkIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Activate Framework", HrefPrefix: "/regulatory_frameworks/activate_framework/new?id=", Allowed: true}, {Label: "Retire Framework", HrefPrefix: "/regulatory_frameworks/retire_framework", Allowed: true, Direct: true, IdField: "framework_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, RegulatoryFrameworkIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/regulatory_frameworks/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Jurisdiction), fmt.Sprintf("%v", obj.Version), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.Authority), fmt.Sprintf("%d items", len(obj.Requirements)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "RegulatoryFrameworks", RegulatoryFrameworkIndexData{AggregateName: "RegulatoryFramework", Description: "External regulatory requirements and their articles", Items: rows, Columns: []RegulatoryFrameworkColumn{{Label: "Name"}, {Label: "Jurisdiction"}, {Label: "Version"}, {Label: "Effective Date"}, {Label: "Authority"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []RegulatoryFrameworkButton{{Label: "Register Framework", Href: "/regulatory_frameworks/register_framework/new", Allowed: true}}, RowActions: []RowAction{{Label: "Activate Framework", HrefPrefix: "/regulatory_frameworks/activate_framework/new?id=", Allowed: true}, {Label: "Retire Framework", HrefPrefix: "/regulatory_frameworks/retire_framework", Allowed: true, Direct: true, IdField: "framework_id"}}})
	})

	mux.HandleFunc("GET /regulatory_frameworks/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.RegulatoryFrameworkRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /regulatory_frameworks/register_framework", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RegisterFramework
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Jurisdiction = r.FormValue("jurisdiction")
			cmd.Version = r.FormValue("version")
			cmd.Authority = r.FormValue("authority")
		}
		agg, event, err := cmd.Execute(app.RegulatoryFrameworkRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/regulatory_frameworks/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /regulatory_frameworks/activate_framework", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ActivateFramework
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.FrameworkId = r.FormValue("framework_id")
			if v := r.FormValue("effective_date"); v != "" { cmd.EffectiveDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.RegulatoryFrameworkRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/regulatory_frameworks/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /regulatory_frameworks/retire_framework", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RetireFramework
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.FrameworkId = r.FormValue("framework_id")
		}
		agg, event, err := cmd.Execute(app.RegulatoryFrameworkRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/regulatory_frameworks/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type ComplianceReviewColumn struct { Label string }
	type ComplianceReviewIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type ComplianceReviewButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type ComplianceReviewIndexData struct { AggregateName string; Description string; Items []ComplianceReviewIndexItem; Columns []ComplianceReviewColumn; Buttons []ComplianceReviewButton; RowActions []RowAction }
	mux.HandleFunc("GET /compliance_reviews", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.ComplianceReviewRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.ComplianceReviewRepo.All()
		var rows []ComplianceReviewIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Approve Review", HrefPrefix: "/compliance_reviews/approve_review/new?id=", Allowed: true}, {Label: "Reject Review", HrefPrefix: "/compliance_reviews/reject_review/new?id=", Allowed: true}, {Label: "Request Changes", HrefPrefix: "/compliance_reviews/request_changes/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, ComplianceReviewIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/compliance_reviews/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.ReviewerId), fmt.Sprintf("%v", obj.Outcome), fmt.Sprintf("%v", obj.Notes), fmt.Sprintf("%v", obj.CompletedAt), fmt.Sprintf("%d items", len(obj.Conditions)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "ComplianceReviews", ComplianceReviewIndexData{AggregateName: "ComplianceReview", Description: "Reviews of AI models against governance policies", Items: rows, Columns: []ComplianceReviewColumn{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Reviewer Id"}, {Label: "Outcome"}, {Label: "Notes"}, {Label: "Completed At"}, {Label: "Conditions"}, {Label: "Status"}}, Buttons: []ComplianceReviewButton{{Label: "Open Review", Href: "/compliance_reviews/open_review/new", Allowed: true}}, RowActions: []RowAction{{Label: "Approve Review", HrefPrefix: "/compliance_reviews/approve_review/new?id=", Allowed: true}, {Label: "Reject Review", HrefPrefix: "/compliance_reviews/reject_review/new?id=", Allowed: true}, {Label: "Request Changes", HrefPrefix: "/compliance_reviews/request_changes/new?id=", Allowed: true}}})
	})

	mux.HandleFunc("GET /compliance_reviews/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.ComplianceReviewRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /compliance_reviews/open_review", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.OpenReview
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.PolicyId = r.FormValue("policy_id")
			cmd.ReviewerId = r.FormValue("reviewer_id")
		}
		agg, event, err := cmd.Execute(app.ComplianceReviewRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/compliance_reviews/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /compliance_reviews/approve_review", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ApproveReview
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ReviewId = r.FormValue("review_id")
			cmd.Notes = r.FormValue("notes")
		}
		agg, event, err := cmd.Execute(app.ComplianceReviewRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/compliance_reviews/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /compliance_reviews/reject_review", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RejectReview
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ReviewId = r.FormValue("review_id")
			cmd.Notes = r.FormValue("notes")
		}
		agg, event, err := cmd.Execute(app.ComplianceReviewRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/compliance_reviews/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /compliance_reviews/request_changes", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RequestChanges
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ReviewId = r.FormValue("review_id")
			cmd.Notes = r.FormValue("notes")
		}
		agg, event, err := cmd.Execute(app.ComplianceReviewRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/compliance_reviews/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type ExemptionColumn struct { Label string }
	type ExemptionIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type ExemptionButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type ExemptionIndexData struct { AggregateName string; Description string; Items []ExemptionIndexItem; Columns []ExemptionColumn; Buttons []ExemptionButton; RowActions []RowAction }
	mux.HandleFunc("GET /exemptions", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.ExemptionRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.ExemptionRepo.All()
		var rows []ExemptionIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Approve Exemption", HrefPrefix: "/exemptions/approve_exemption/new?id=", Allowed: true}, {Label: "Revoke Exemption", HrefPrefix: "/exemptions/revoke_exemption", Allowed: true, Direct: true, IdField: "exemption_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, ExemptionIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/exemptions/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.Requirement), fmt.Sprintf("%v", obj.Reason), fmt.Sprintf("%v", obj.ApprovedById), fmt.Sprintf("%v", obj.ApprovedAt), fmt.Sprintf("%v", obj.ExpiresAt), fmt.Sprintf("%v", obj.Scope), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Exemptions", ExemptionIndexData{AggregateName: "Exemption", Description: "Approved exceptions to policy requirements", Items: rows, Columns: []ExemptionColumn{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Requirement"}, {Label: "Reason"}, {Label: "Approved By Id"}, {Label: "Approved At"}, {Label: "Expires At"}, {Label: "Scope"}, {Label: "Status"}}, Buttons: []ExemptionButton{{Label: "Request Exemption", Href: "/exemptions/request_exemption/new", Allowed: true}}, RowActions: []RowAction{{Label: "Approve Exemption", HrefPrefix: "/exemptions/approve_exemption/new?id=", Allowed: true}, {Label: "Revoke Exemption", HrefPrefix: "/exemptions/revoke_exemption", Allowed: true, Direct: true, IdField: "exemption_id"}}})
	})

	mux.HandleFunc("GET /exemptions/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.ExemptionRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /exemptions/request_exemption", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RequestExemption
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.PolicyId = r.FormValue("policy_id")
			cmd.Requirement = r.FormValue("requirement")
			cmd.Reason = r.FormValue("reason")
		}
		agg, event, err := cmd.Execute(app.ExemptionRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/exemptions/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /exemptions/approve_exemption", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ApproveExemption
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ExemptionId = r.FormValue("exemption_id")
			cmd.ApprovedById = r.FormValue("approved_by_id")
			if v := r.FormValue("expires_at"); v != "" { cmd.ExpiresAt, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.ExemptionRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/exemptions/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /exemptions/revoke_exemption", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RevokeExemption
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ExemptionId = r.FormValue("exemption_id")
		}
		agg, event, err := cmd.Execute(app.ExemptionRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/exemptions/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type TrainingRecordColumn struct { Label string }
	type TrainingRecordIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type TrainingRecordButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type TrainingRecordIndexData struct { AggregateName string; Description string; Items []TrainingRecordIndexItem; Columns []TrainingRecordColumn; Buttons []TrainingRecordButton; RowActions []RowAction }
	mux.HandleFunc("GET /training_records", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.TrainingRecordRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.TrainingRecordRepo.All()
		var rows []TrainingRecordIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Complete Training", HrefPrefix: "/training_records/complete_training/new?id=", Allowed: true}, {Label: "Renew Training", HrefPrefix: "/training_records/renew_training/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, TrainingRecordIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/training_records/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.StakeholderId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.CompletedAt), fmt.Sprintf("%v", obj.ExpiresAt), fmt.Sprintf("%v", obj.Certification), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "TrainingRecords", TrainingRecordIndexData{AggregateName: "TrainingRecord", Description: "Staff training completion and certification tracking", Items: rows, Columns: []TrainingRecordColumn{{Label: "Stakeholder Id"}, {Label: "Policy Id"}, {Label: "Completed At"}, {Label: "Expires At"}, {Label: "Certification"}, {Label: "Status"}}, Buttons: []TrainingRecordButton{{Label: "Assign Training", Href: "/training_records/assign_training/new", Allowed: true}}, RowActions: []RowAction{{Label: "Complete Training", HrefPrefix: "/training_records/complete_training/new?id=", Allowed: true}, {Label: "Renew Training", HrefPrefix: "/training_records/renew_training/new?id=", Allowed: true}}})
	})

	mux.HandleFunc("GET /training_records/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.TrainingRecordRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /training_records/assign_training", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.AssignTraining
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.StakeholderId = r.FormValue("stakeholder_id")
			cmd.PolicyId = r.FormValue("policy_id")
		}
		agg, event, err := cmd.Execute(app.TrainingRecordRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/training_records/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /training_records/complete_training", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CompleteTraining
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.TrainingRecordId = r.FormValue("training_record_id")
			cmd.Certification = r.FormValue("certification")
			if v := r.FormValue("expires_at"); v != "" { cmd.ExpiresAt, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.TrainingRecordRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/training_records/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /training_records/renew_training", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RenewTraining
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.TrainingRecordId = r.FormValue("training_record_id")
			cmd.Certification = r.FormValue("certification")
			if v := r.FormValue("expires_at"); v != "" { cmd.ExpiresAt, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.TrainingRecordRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/training_records/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type StakeholderColumn struct { Label string }
	type StakeholderIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type StakeholderButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type StakeholderIndexData struct { AggregateName string; Description string; Items []StakeholderIndexItem; Columns []StakeholderColumn; Buttons []StakeholderButton; RowActions []RowAction }
	mux.HandleFunc("GET /stakeholders", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.StakeholderRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.StakeholderRepo.All()
		var rows []StakeholderIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Assign Role", HrefPrefix: "/stakeholders/assign_role/new?id=", Allowed: true}, {Label: "Deactivate Stakeholder", HrefPrefix: "/stakeholders/deactivate_stakeholder", Allowed: true, Direct: true, IdField: "stakeholder_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, StakeholderIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/stakeholders/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Email), fmt.Sprintf("%v", obj.Role), fmt.Sprintf("%v", obj.Team), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Stakeholders", StakeholderIndexData{AggregateName: "Stakeholder", Description: "Users, roles, and permissions for governance participants", Items: rows, Columns: []StakeholderColumn{{Label: "Name"}, {Label: "Email"}, {Label: "Role"}, {Label: "Team"}, {Label: "Status"}}, Buttons: []StakeholderButton{{Label: "Register Stakeholder", Href: "/stakeholders/register_stakeholder/new", Allowed: true}}, RowActions: []RowAction{{Label: "Assign Role", HrefPrefix: "/stakeholders/assign_role/new?id=", Allowed: true}, {Label: "Deactivate Stakeholder", HrefPrefix: "/stakeholders/deactivate_stakeholder", Allowed: true, Direct: true, IdField: "stakeholder_id"}}})
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

	type AuditLogColumn struct { Label string }
	type AuditLogIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type AuditLogButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type AuditLogIndexData struct { AggregateName string; Description string; Items []AuditLogIndexItem; Columns []AuditLogColumn; Buttons []AuditLogButton; RowActions []RowAction }
	mux.HandleFunc("GET /audit_logs", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AuditLogRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AuditLogRepo.All()
		var rows []AuditLogIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, AuditLogIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/audit_logs/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.EntityType), fmt.Sprintf("%v", obj.EntityId), fmt.Sprintf("%v", obj.Action), fmt.Sprintf("%v", obj.ActorId), fmt.Sprintf("%v", obj.Details), fmt.Sprintf("%v", obj.Timestamp)}, RowActions: actions})
		}
		renderer.Render(w, "index", "AuditLogs", AuditLogIndexData{AggregateName: "AuditLog", Description: "Immutable record of all actions across the governance system", Items: rows, Columns: []AuditLogColumn{{Label: "Entity Type"}, {Label: "Entity Id"}, {Label: "Action"}, {Label: "Actor Id"}, {Label: "Details"}, {Label: "Timestamp"}}, Buttons: []AuditLogButton{{Label: "Record Entry", Href: "/audit_logs/record_entry/new", Allowed: true}}, RowActions: []RowAction{}})
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

	type AiModelColumn struct { Label string }
	type AiModelIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type AiModelButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type AiModelIndexData struct { AggregateName string; Description string; Items []AiModelIndexItem; Columns []AiModelColumn; Buttons []AiModelButton; RowActions []RowAction }
	mux.HandleFunc("GET /ai_models", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AiModelRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AiModelRepo.All()
		var rows []AiModelIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Classify Risk", HrefPrefix: "/ai_models/classify_risk/new?id=", Allowed: true}, {Label: "Approve Model", HrefPrefix: "/ai_models/approve_model", Allowed: true, Direct: true, IdField: "model_id"}, {Label: "Suspend Model", HrefPrefix: "/ai_models/suspend_model", Allowed: true, Direct: true, IdField: "model_id"}, {Label: "Retire Model", HrefPrefix: "/ai_models/retire_model", Allowed: true, Direct: true, IdField: "model_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, AiModelIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/ai_models/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Version), fmt.Sprintf("%v", obj.ProviderId), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.RiskLevel), fmt.Sprintf("%v", obj.RegisteredAt), fmt.Sprintf("%v", obj.ParentModelId), fmt.Sprintf("%v", obj.DerivationType), fmt.Sprintf("%d items", len(obj.Capabilities)), fmt.Sprintf("%d items", len(obj.IntendedUses)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "AiModels", AiModelIndexData{AggregateName: "AiModel", Description: "AI models registered for governance oversight", Items: rows, Columns: []AiModelColumn{{Label: "Name"}, {Label: "Version"}, {Label: "Provider Id"}, {Label: "Description"}, {Label: "Risk Level"}, {Label: "Registered At"}, {Label: "Parent Model Id"}, {Label: "Derivation Type"}, {Label: "Capabilities"}, {Label: "Intended Uses"}, {Label: "Status"}}, Buttons: []AiModelButton{{Label: "Register Model", Href: "/ai_models/register_model/new", Allowed: true}, {Label: "Derive Model", Href: "/ai_models/derive_model/new", Allowed: true}}, RowActions: []RowAction{{Label: "Classify Risk", HrefPrefix: "/ai_models/classify_risk/new?id=", Allowed: true}, {Label: "Approve Model", HrefPrefix: "/ai_models/approve_model", Allowed: true, Direct: true, IdField: "model_id"}, {Label: "Suspend Model", HrefPrefix: "/ai_models/suspend_model", Allowed: true, Direct: true, IdField: "model_id"}, {Label: "Retire Model", HrefPrefix: "/ai_models/retire_model", Allowed: true, Direct: true, IdField: "model_id"}}})
	})

	mux.HandleFunc("GET /ai_models/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.AiModelRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /ai_models/register_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RegisterModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Version = r.FormValue("version")
			cmd.ProviderId = r.FormValue("provider_id")
			cmd.Description = r.FormValue("description")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /ai_models/derive_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.DeriveModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.Version = r.FormValue("version")
			cmd.ParentModelId = r.FormValue("parent_model_id")
			cmd.DerivationType = r.FormValue("derivation_type")
			cmd.Description = r.FormValue("description")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /ai_models/classify_risk", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ClassifyRisk
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.RiskLevel = r.FormValue("risk_level")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /ai_models/approve_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ApproveModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /ai_models/suspend_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.SuspendModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /ai_models/retire_model", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RetireModel
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
		}
		agg, event, err := cmd.Execute(app.AiModelRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/ai_models/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type VendorColumn struct { Label string }
	type VendorIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type VendorButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type VendorIndexData struct { AggregateName string; Description string; Items []VendorIndexItem; Columns []VendorColumn; Buttons []VendorButton; RowActions []RowAction }
	mux.HandleFunc("GET /vendors", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.VendorRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.VendorRepo.All()
		var rows []VendorIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Approve Vendor", HrefPrefix: "/vendors/approve_vendor/new?id=", Allowed: true}, {Label: "Suspend Vendor", HrefPrefix: "/vendors/suspend_vendor", Allowed: true, Direct: true, IdField: "vendor_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, VendorIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/vendors/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.ContactEmail), fmt.Sprintf("%v", obj.RiskTier), fmt.Sprintf("%v", obj.AssessmentDate), fmt.Sprintf("%v", obj.NextReviewDate), fmt.Sprintf("%v", obj.SlaTerms), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Vendors", VendorIndexData{AggregateName: "Vendor", Description: "Third-party AI model providers and their risk assessments", Items: rows, Columns: []VendorColumn{{Label: "Name"}, {Label: "Contact Email"}, {Label: "Risk Tier"}, {Label: "Assessment Date"}, {Label: "Next Review Date"}, {Label: "Sla Terms"}, {Label: "Status"}}, Buttons: []VendorButton{{Label: "Register Vendor", Href: "/vendors/register_vendor/new", Allowed: true}}, RowActions: []RowAction{{Label: "Approve Vendor", HrefPrefix: "/vendors/approve_vendor/new?id=", Allowed: true}, {Label: "Suspend Vendor", HrefPrefix: "/vendors/suspend_vendor", Allowed: true, Direct: true, IdField: "vendor_id"}}})
	})

	mux.HandleFunc("GET /vendors/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.VendorRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /vendors/register_vendor", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RegisterVendor
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.Name = r.FormValue("name")
			cmd.ContactEmail = r.FormValue("contact_email")
			cmd.RiskTier = r.FormValue("risk_tier")
		}
		agg, event, err := cmd.Execute(app.VendorRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/vendors/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /vendors/approve_vendor", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ApproveVendor
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.VendorId = r.FormValue("vendor_id")
			if v := r.FormValue("assessment_date"); v != "" { cmd.AssessmentDate, _ = time.Parse("2006-01-02", v) }
			if v := r.FormValue("next_review_date"); v != "" { cmd.NextReviewDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.VendorRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/vendors/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /vendors/suspend_vendor", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.SuspendVendor
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.VendorId = r.FormValue("vendor_id")
		}
		agg, event, err := cmd.Execute(app.VendorRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/vendors/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type DataUsageAgreementColumn struct { Label string }
	type DataUsageAgreementIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type DataUsageAgreementButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type DataUsageAgreementIndexData struct { AggregateName string; Description string; Items []DataUsageAgreementIndexItem; Columns []DataUsageAgreementColumn; Buttons []DataUsageAgreementButton; RowActions []RowAction }
	mux.HandleFunc("GET /data_usage_agreements", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.DataUsageAgreementRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.DataUsageAgreementRepo.All()
		var rows []DataUsageAgreementIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Activate Agreement", HrefPrefix: "/data_usage_agreements/activate_agreement/new?id=", Allowed: true}, {Label: "Revoke Agreement", HrefPrefix: "/data_usage_agreements/revoke_agreement", Allowed: true, Direct: true, IdField: "agreement_id"}, {Label: "Renew Agreement", HrefPrefix: "/data_usage_agreements/renew_agreement/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, DataUsageAgreementIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/data_usage_agreements/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.DataSource), fmt.Sprintf("%v", obj.Purpose), fmt.Sprintf("%v", obj.ConsentType), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.ExpirationDate), fmt.Sprintf("%d items", len(obj.Restrictions)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "DataUsageAgreements", DataUsageAgreementIndexData{AggregateName: "DataUsageAgreement", Description: "Agreements governing data usage for model training and inference", Items: rows, Columns: []DataUsageAgreementColumn{{Label: "Model Id"}, {Label: "Data Source"}, {Label: "Purpose"}, {Label: "Consent Type"}, {Label: "Effective Date"}, {Label: "Expiration Date"}, {Label: "Restrictions"}, {Label: "Status"}}, Buttons: []DataUsageAgreementButton{{Label: "Create Agreement", Href: "/data_usage_agreements/create_agreement/new", Allowed: true}}, RowActions: []RowAction{{Label: "Activate Agreement", HrefPrefix: "/data_usage_agreements/activate_agreement/new?id=", Allowed: true}, {Label: "Revoke Agreement", HrefPrefix: "/data_usage_agreements/revoke_agreement", Allowed: true, Direct: true, IdField: "agreement_id"}, {Label: "Renew Agreement", HrefPrefix: "/data_usage_agreements/renew_agreement/new?id=", Allowed: true}}})
	})

	mux.HandleFunc("GET /data_usage_agreements/find", func(w http.ResponseWriter, r *http.Request) {
		item, _ := app.DataUsageAgreementRepo.Find(r.URL.Query().Get("id"))
		if item == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		jsonResponse(w, item)
	})

	mux.HandleFunc("POST /data_usage_agreements/create_agreement", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.CreateAgreement
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.ModelId = r.FormValue("model_id")
			cmd.DataSource = r.FormValue("data_source")
			cmd.Purpose = r.FormValue("purpose")
			cmd.ConsentType = r.FormValue("consent_type")
		}
		agg, event, err := cmd.Execute(app.DataUsageAgreementRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/data_usage_agreements/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /data_usage_agreements/activate_agreement", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.ActivateAgreement
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AgreementId = r.FormValue("agreement_id")
			if v := r.FormValue("effective_date"); v != "" { cmd.EffectiveDate, _ = time.Parse("2006-01-02", v) }
			if v := r.FormValue("expiration_date"); v != "" { cmd.ExpirationDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.DataUsageAgreementRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/data_usage_agreements/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /data_usage_agreements/revoke_agreement", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RevokeAgreement
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AgreementId = r.FormValue("agreement_id")
		}
		agg, event, err := cmd.Execute(app.DataUsageAgreementRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/data_usage_agreements/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	mux.HandleFunc("POST /data_usage_agreements/renew_agreement", func(w http.ResponseWriter, r *http.Request) {
		var cmd domain.RenewAgreement
		if r.Header.Get("Content-Type") == "application/json" {
			if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil { http.Error(w, `{"error":"invalid json"}`, 400); return }
		} else {
			r.ParseForm()
			cmd.AgreementId = r.FormValue("agreement_id")
			if v := r.FormValue("expiration_date"); v != "" { cmd.ExpirationDate, _ = time.Parse("2006-01-02", v) }
		}
		agg, event, err := cmd.Execute(app.DataUsageAgreementRepo)
		if event != nil { app.EventBus.Publish(event) }
		if err != nil {
			if r.Header.Get("Content-Type")=="application/json" { jsonError(w, err); return }
			http.Error(w, err.Error(), 422); return
		}
		if r.Header.Get("Content-Type")=="application/json" { w.WriteHeader(201); jsonResponse(w, agg) } else {
			http.Redirect(w, r, "/data_usage_agreements/show?id="+agg.ID, http.StatusSeeOther)
		}
	})

	type DeploymentColumn struct { Label string }
	type DeploymentIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type DeploymentButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type DeploymentIndexData struct { AggregateName string; Description string; Items []DeploymentIndexItem; Columns []DeploymentColumn; Buttons []DeploymentButton; RowActions []RowAction }
	mux.HandleFunc("GET /deployments", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.DeploymentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.DeploymentRepo.All()
		var rows []DeploymentIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Deploy Model", HrefPrefix: "/deployments/deploy_model", Allowed: true, Direct: true, IdField: "deployment_id"}, {Label: "Decommission Deployment", HrefPrefix: "/deployments/decommission_deployment", Allowed: true, Direct: true, IdField: "deployment_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, DeploymentIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/deployments/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.Environment), fmt.Sprintf("%v", obj.Endpoint), fmt.Sprintf("%v", obj.Purpose), fmt.Sprintf("%v", obj.Audience), fmt.Sprintf("%v", obj.DeployedAt), fmt.Sprintf("%v", obj.DecommissionedAt), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Deployments", DeploymentIndexData{AggregateName: "Deployment", Description: "AI model deployments across environments", Items: rows, Columns: []DeploymentColumn{{Label: "Model Id"}, {Label: "Environment"}, {Label: "Endpoint"}, {Label: "Purpose"}, {Label: "Audience"}, {Label: "Deployed At"}, {Label: "Decommissioned At"}, {Label: "Status"}}, Buttons: []DeploymentButton{{Label: "Plan Deployment", Href: "/deployments/plan_deployment/new", Allowed: true}}, RowActions: []RowAction{{Label: "Deploy Model", HrefPrefix: "/deployments/deploy_model", Allowed: true, Direct: true, IdField: "deployment_id"}, {Label: "Decommission Deployment", HrefPrefix: "/deployments/decommission_deployment", Allowed: true, Direct: true, IdField: "deployment_id"}}})
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

	type IncidentColumn struct { Label string }
	type IncidentIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type IncidentButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type IncidentIndexData struct { AggregateName string; Description string; Items []IncidentIndexItem; Columns []IncidentColumn; Buttons []IncidentButton; RowActions []RowAction }
	mux.HandleFunc("GET /incidents", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.IncidentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.IncidentRepo.All()
		var rows []IncidentIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Investigate Incident", HrefPrefix: "/incidents/investigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, {Label: "Mitigate Incident", HrefPrefix: "/incidents/mitigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, {Label: "Resolve Incident", HrefPrefix: "/incidents/resolve_incident/new?id=", Allowed: true}, {Label: "Close Incident", HrefPrefix: "/incidents/close_incident", Allowed: true, Direct: true, IdField: "incident_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, IncidentIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/incidents/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.Severity), fmt.Sprintf("%v", obj.Category), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.ReportedById), fmt.Sprintf("%v", obj.ReportedAt), fmt.Sprintf("%v", obj.ResolvedAt), fmt.Sprintf("%v", obj.Resolution), fmt.Sprintf("%v", obj.RootCause), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Incidents", IncidentIndexData{AggregateName: "Incident", Description: "AI-related incidents including bias, safety, and performance issues", Items: rows, Columns: []IncidentColumn{{Label: "Model Id"}, {Label: "Severity"}, {Label: "Category"}, {Label: "Description"}, {Label: "Reported By Id"}, {Label: "Reported At"}, {Label: "Resolved At"}, {Label: "Resolution"}, {Label: "Root Cause"}, {Label: "Status"}}, Buttons: []IncidentButton{{Label: "Report Incident", Href: "/incidents/report_incident/new", Allowed: true}}, RowActions: []RowAction{{Label: "Investigate Incident", HrefPrefix: "/incidents/investigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, {Label: "Mitigate Incident", HrefPrefix: "/incidents/mitigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, {Label: "Resolve Incident", HrefPrefix: "/incidents/resolve_incident/new?id=", Allowed: true}, {Label: "Close Incident", HrefPrefix: "/incidents/close_incident", Allowed: true, Direct: true, IdField: "incident_id"}}})
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

	type MonitoringColumn struct { Label string }
	type MonitoringIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type MonitoringButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type MonitoringIndexData struct { AggregateName string; Description string; Items []MonitoringIndexItem; Columns []MonitoringColumn; Buttons []MonitoringButton; RowActions []RowAction }
	mux.HandleFunc("GET /monitorings", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.MonitoringRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.MonitoringRepo.All()
		var rows []MonitoringIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Set Threshold", HrefPrefix: "/monitorings/set_threshold/new?id=", Allowed: true}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, MonitoringIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/monitorings/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.DeploymentId), fmt.Sprintf("%v", obj.MetricName), fmt.Sprintf("%v", obj.Value), fmt.Sprintf("%v", obj.Threshold), fmt.Sprintf("%v", obj.RecordedAt)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Monitorings", MonitoringIndexData{AggregateName: "Monitoring", Description: "Performance and safety metrics for deployed models", Items: rows, Columns: []MonitoringColumn{{Label: "Model Id"}, {Label: "Deployment Id"}, {Label: "Metric Name"}, {Label: "Value"}, {Label: "Threshold"}, {Label: "Recorded At"}}, Buttons: []MonitoringButton{{Label: "Record Metric", Href: "/monitorings/record_metric/new", Allowed: true}}, RowActions: []RowAction{{Label: "Set Threshold", HrefPrefix: "/monitorings/set_threshold/new?id=", Allowed: true}}})
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

	type AssessmentColumn struct { Label string }
	type AssessmentIndexItem struct { Id string; ShortId string; ShowHref string; Cells []string; RowActions []RowAction }
	type AssessmentButton struct { Label string; Href string; Allowed bool; Direct bool; IdField string }
	type AssessmentIndexData struct { AggregateName string; Description string; Items []AssessmentIndexItem; Columns []AssessmentColumn; Buttons []AssessmentButton; RowActions []RowAction }
	mux.HandleFunc("GET /assessments", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AssessmentRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AssessmentRepo.All()
		var rows []AssessmentIndexItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			baseActions := []RowAction{{Label: "Record Finding", HrefPrefix: "/assessments/record_finding/new?id=", Allowed: true}, {Label: "Submit Assessment", HrefPrefix: "/assessments/submit_assessment/new?id=", Allowed: true}, {Label: "Reject Assessment", HrefPrefix: "/assessments/reject_assessment", Allowed: true, Direct: true, IdField: "assessment_id"}}
			actions := make([]RowAction, len(baseActions))
			for i, a := range baseActions { actions[i] = RowAction{Label: a.Label, HrefPrefix: a.HrefPrefix, Id: obj.ID, Allowed: a.Allowed, Direct: a.Direct, IdField: a.IdField} }
			rows = append(rows, AssessmentIndexItem{Id: obj.ID, ShortId: sid, ShowHref: "/assessments/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.AssessorId), fmt.Sprintf("%v", obj.RiskLevel), fmt.Sprintf("%v", obj.BiasScore), fmt.Sprintf("%v", obj.SafetyScore), fmt.Sprintf("%v", obj.TransparencyScore), fmt.Sprintf("%v", obj.OverallScore), fmt.Sprintf("%v", obj.SubmittedAt), fmt.Sprintf("%d items", len(obj.Findings)), fmt.Sprintf("%d items", len(obj.Mitigations)), fmt.Sprintf("%v", obj.Status)}, RowActions: actions})
		}
		renderer.Render(w, "index", "Assessments", AssessmentIndexData{AggregateName: "Assessment", Description: "Risk assessments evaluating AI model safety, bias, and transparency", Items: rows, Columns: []AssessmentColumn{{Label: "Model Id"}, {Label: "Assessor Id"}, {Label: "Risk Level"}, {Label: "Bias Score"}, {Label: "Safety Score"}, {Label: "Transparency Score"}, {Label: "Overall Score"}, {Label: "Submitted At"}, {Label: "Findings"}, {Label: "Mitigations"}, {Label: "Status"}}, Buttons: []AssessmentButton{{Label: "Initiate Assessment", Href: "/assessments/initiate_assessment/new", Allowed: true}}, RowActions: []RowAction{{Label: "Record Finding", HrefPrefix: "/assessments/record_finding/new?id=", Allowed: true}, {Label: "Submit Assessment", HrefPrefix: "/assessments/submit_assessment/new?id=", Allowed: true}, {Label: "Reject Assessment", HrefPrefix: "/assessments/reject_assessment", Allowed: true, Direct: true, IdField: "assessment_id"}}})
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

	type GovernancePolicyShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type GovernancePolicyShowData struct { AggregateName string; Id string; BackHref string; Fields []GovernancePolicyShowField; Buttons []GovernancePolicyButton }
	mux.HandleFunc("GET /governance_policys/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.GovernancePolicyRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []GovernancePolicyShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Category", Value: fmt.Sprintf("%v", obj.Category)},
			{Label: "Framework Id", Value: fmt.Sprintf("%v", obj.FrameworkId)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Review Date", Value: fmt.Sprintf("%v", obj.ReviewDate)},
			{Label: "Requirements", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Requirements { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Create Policy → draft", "Activate Policy → active", "Suspend Policy → suspended", "Retire Policy → retired"}},
		}
		buttons := []GovernancePolicyButton{GovernancePolicyButton{Label: "Activate Policy", Href: "/governance_policys/activate_policy/new?id=" + obj.ID, Allowed: true}, GovernancePolicyButton{Label: "Suspend Policy", Href: "/governance_policys/suspend_policy", Allowed: true, Direct: true, IdField: "policy_id"}, GovernancePolicyButton{Label: "Retire Policy", Href: "/governance_policys/retire_policy", Allowed: true, Direct: true, IdField: "policy_id"}, GovernancePolicyButton{Label: "Update Review Date", Href: "/governance_policys/update_review_date/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "GovernancePolicy", GovernancePolicyShowData{AggregateName: "GovernancePolicy", BackHref: "/governance_policys", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type RegulatoryFrameworkShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type RegulatoryFrameworkShowData struct { AggregateName string; Id string; BackHref string; Fields []RegulatoryFrameworkShowField; Buttons []RegulatoryFrameworkButton }
	mux.HandleFunc("GET /regulatory_frameworks/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.RegulatoryFrameworkRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []RegulatoryFrameworkShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Jurisdiction", Value: fmt.Sprintf("%v", obj.Jurisdiction)},
			{Label: "Version", Value: fmt.Sprintf("%v", obj.Version)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Authority", Value: fmt.Sprintf("%v", obj.Authority)},
			{Label: "Requirements", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Requirements { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Register Framework → draft", "Activate Framework → active", "Retire Framework → retired"}},
		}
		buttons := []RegulatoryFrameworkButton{RegulatoryFrameworkButton{Label: "Activate Framework", Href: "/regulatory_frameworks/activate_framework/new?id=" + obj.ID, Allowed: true}, RegulatoryFrameworkButton{Label: "Retire Framework", Href: "/regulatory_frameworks/retire_framework", Allowed: true, Direct: true, IdField: "framework_id"}}
		renderer.Render(w, "show", "RegulatoryFramework", RegulatoryFrameworkShowData{AggregateName: "RegulatoryFramework", BackHref: "/regulatory_frameworks", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type ComplianceReviewShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type ComplianceReviewShowData struct { AggregateName string; Id string; BackHref string; Fields []ComplianceReviewShowField; Buttons []ComplianceReviewButton }
	mux.HandleFunc("GET /compliance_reviews/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.ComplianceReviewRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []ComplianceReviewShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Reviewer Id", Value: fmt.Sprintf("%v", obj.ReviewerId)},
			{Label: "Outcome", Value: fmt.Sprintf("%v", obj.Outcome)},
			{Label: "Notes", Value: fmt.Sprintf("%v", obj.Notes)},
			{Label: "Completed At", Value: fmt.Sprintf("%v", obj.CompletedAt)},
			{Label: "Conditions", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Conditions { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Open Review → open", "Approve Review → approved", "Reject Review → rejected", "Request Changes → changes_requested"}},
		}
		buttons := []ComplianceReviewButton{ComplianceReviewButton{Label: "Approve Review", Href: "/compliance_reviews/approve_review/new?id=" + obj.ID, Allowed: true}, ComplianceReviewButton{Label: "Reject Review", Href: "/compliance_reviews/reject_review/new?id=" + obj.ID, Allowed: true}, ComplianceReviewButton{Label: "Request Changes", Href: "/compliance_reviews/request_changes/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "ComplianceReview", ComplianceReviewShowData{AggregateName: "ComplianceReview", BackHref: "/compliance_reviews", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type ExemptionShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type ExemptionShowData struct { AggregateName string; Id string; BackHref string; Fields []ExemptionShowField; Buttons []ExemptionButton }
	mux.HandleFunc("GET /exemptions/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.ExemptionRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []ExemptionShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Requirement", Value: fmt.Sprintf("%v", obj.Requirement)},
			{Label: "Reason", Value: fmt.Sprintf("%v", obj.Reason)},
			{Label: "Approved By Id", Value: fmt.Sprintf("%v", obj.ApprovedById)},
			{Label: "Approved At", Value: fmt.Sprintf("%v", obj.ApprovedAt)},
			{Label: "Expires At", Value: fmt.Sprintf("%v", obj.ExpiresAt)},
			{Label: "Scope", Value: fmt.Sprintf("%v", obj.Scope)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Request Exemption → requested", "Approve Exemption → active", "Revoke Exemption → revoked"}},
		}
		buttons := []ExemptionButton{ExemptionButton{Label: "Approve Exemption", Href: "/exemptions/approve_exemption/new?id=" + obj.ID, Allowed: true}, ExemptionButton{Label: "Revoke Exemption", Href: "/exemptions/revoke_exemption", Allowed: true, Direct: true, IdField: "exemption_id"}}
		renderer.Render(w, "show", "Exemption", ExemptionShowData{AggregateName: "Exemption", BackHref: "/exemptions", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type TrainingRecordShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type TrainingRecordShowData struct { AggregateName string; Id string; BackHref string; Fields []TrainingRecordShowField; Buttons []TrainingRecordButton }
	mux.HandleFunc("GET /training_records/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.TrainingRecordRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []TrainingRecordShowField{
			{Label: "Stakeholder Id", Value: fmt.Sprintf("%v", obj.StakeholderId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Completed At", Value: fmt.Sprintf("%v", obj.CompletedAt)},
			{Label: "Expires At", Value: fmt.Sprintf("%v", obj.ExpiresAt)},
			{Label: "Certification", Value: fmt.Sprintf("%v", obj.Certification)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Assign Training → assigned", "Complete Training → completed", "Renew Training → completed"}},
		}
		buttons := []TrainingRecordButton{TrainingRecordButton{Label: "Complete Training", Href: "/training_records/complete_training/new?id=" + obj.ID, Allowed: true}, TrainingRecordButton{Label: "Renew Training", Href: "/training_records/renew_training/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "TrainingRecord", TrainingRecordShowData{AggregateName: "TrainingRecord", BackHref: "/training_records", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type StakeholderShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type StakeholderShowData struct { AggregateName string; Id string; BackHref string; Fields []StakeholderShowField; Buttons []StakeholderButton }
	mux.HandleFunc("GET /stakeholders/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.StakeholderRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []StakeholderShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Email", Value: fmt.Sprintf("%v", obj.Email)},
			{Label: "Role", Value: fmt.Sprintf("%v", obj.Role)},
			{Label: "Team", Value: fmt.Sprintf("%v", obj.Team)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Register Stakeholder → active", "Deactivate Stakeholder → deactivated"}},
		}
		buttons := []StakeholderButton{StakeholderButton{Label: "Assign Role", Href: "/stakeholders/assign_role/new?id=" + obj.ID, Allowed: true}, StakeholderButton{Label: "Deactivate Stakeholder", Href: "/stakeholders/deactivate_stakeholder", Allowed: true, Direct: true, IdField: "stakeholder_id"}}
		renderer.Render(w, "show", "Stakeholder", StakeholderShowData{AggregateName: "Stakeholder", BackHref: "/stakeholders", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type AuditLogShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type AuditLogShowData struct { AggregateName string; Id string; BackHref string; Fields []AuditLogShowField; Buttons []AuditLogButton }
	mux.HandleFunc("GET /audit_logs/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AuditLogRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AuditLogShowField{
			{Label: "Entity Type", Value: fmt.Sprintf("%v", obj.EntityType)},
			{Label: "Entity Id", Value: fmt.Sprintf("%v", obj.EntityId)},
			{Label: "Action", Value: fmt.Sprintf("%v", obj.Action)},
			{Label: "Actor Id", Value: fmt.Sprintf("%v", obj.ActorId)},
			{Label: "Details", Value: fmt.Sprintf("%v", obj.Details)},
			{Label: "Timestamp", Value: fmt.Sprintf("%v", obj.Timestamp)},
		}
		var buttons []AuditLogButton
		renderer.Render(w, "show", "AuditLog", AuditLogShowData{AggregateName: "AuditLog", BackHref: "/audit_logs", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type AiModelShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type AiModelShowData struct { AggregateName string; Id string; BackHref string; Fields []AiModelShowField; Buttons []AiModelButton }
	mux.HandleFunc("GET /ai_models/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AiModelRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AiModelShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Version", Value: fmt.Sprintf("%v", obj.Version)},
			{Label: "Provider Id", Value: fmt.Sprintf("%v", obj.ProviderId)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Risk Level", Value: fmt.Sprintf("%v", obj.RiskLevel)},
			{Label: "Registered At", Value: fmt.Sprintf("%v", obj.RegisteredAt)},
			{Label: "Parent Model Id", Value: fmt.Sprintf("%v", obj.ParentModelId)},
			{Label: "Derivation Type", Value: fmt.Sprintf("%v", obj.DerivationType)},
			{Label: "Capabilities", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Capabilities { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Intended Uses", Type: "list", Items: func() []string { var s []string; for _, v := range obj.IntendedUses { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Register Model → draft", "Derive Model → draft", "Classify Risk → classified", "Approve Model → approved", "Suspend Model → suspended", "Retire Model → retired"}},
		}
		buttons := []AiModelButton{AiModelButton{Label: "Classify Risk", Href: "/ai_models/classify_risk/new?id=" + obj.ID, Allowed: true}, AiModelButton{Label: "Approve Model", Href: "/ai_models/approve_model", Allowed: true, Direct: true, IdField: "model_id"}, AiModelButton{Label: "Suspend Model", Href: "/ai_models/suspend_model", Allowed: true, Direct: true, IdField: "model_id"}, AiModelButton{Label: "Retire Model", Href: "/ai_models/retire_model", Allowed: true, Direct: true, IdField: "model_id"}}
		renderer.Render(w, "show", "AiModel", AiModelShowData{AggregateName: "AiModel", BackHref: "/ai_models", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type VendorShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type VendorShowData struct { AggregateName string; Id string; BackHref string; Fields []VendorShowField; Buttons []VendorButton }
	mux.HandleFunc("GET /vendors/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.VendorRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []VendorShowField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Contact Email", Value: fmt.Sprintf("%v", obj.ContactEmail)},
			{Label: "Risk Tier", Value: fmt.Sprintf("%v", obj.RiskTier)},
			{Label: "Assessment Date", Value: fmt.Sprintf("%v", obj.AssessmentDate)},
			{Label: "Next Review Date", Value: fmt.Sprintf("%v", obj.NextReviewDate)},
			{Label: "Sla Terms", Value: fmt.Sprintf("%v", obj.SlaTerms)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Register Vendor → pending_review", "Approve Vendor → approved", "Suspend Vendor → suspended"}},
		}
		buttons := []VendorButton{VendorButton{Label: "Approve Vendor", Href: "/vendors/approve_vendor/new?id=" + obj.ID, Allowed: true}, VendorButton{Label: "Suspend Vendor", Href: "/vendors/suspend_vendor", Allowed: true, Direct: true, IdField: "vendor_id"}}
		renderer.Render(w, "show", "Vendor", VendorShowData{AggregateName: "Vendor", BackHref: "/vendors", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type DataUsageAgreementShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type DataUsageAgreementShowData struct { AggregateName string; Id string; BackHref string; Fields []DataUsageAgreementShowField; Buttons []DataUsageAgreementButton }
	mux.HandleFunc("GET /data_usage_agreements/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DataUsageAgreementRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []DataUsageAgreementShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Data Source", Value: fmt.Sprintf("%v", obj.DataSource)},
			{Label: "Purpose", Value: fmt.Sprintf("%v", obj.Purpose)},
			{Label: "Consent Type", Value: fmt.Sprintf("%v", obj.ConsentType)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Expiration Date", Value: fmt.Sprintf("%v", obj.ExpirationDate)},
			{Label: "Restrictions", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Restrictions { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Create Agreement → draft", "Activate Agreement → active", "Revoke Agreement → revoked", "Renew Agreement → active"}},
		}
		buttons := []DataUsageAgreementButton{DataUsageAgreementButton{Label: "Activate Agreement", Href: "/data_usage_agreements/activate_agreement/new?id=" + obj.ID, Allowed: true}, DataUsageAgreementButton{Label: "Revoke Agreement", Href: "/data_usage_agreements/revoke_agreement", Allowed: true, Direct: true, IdField: "agreement_id"}, DataUsageAgreementButton{Label: "Renew Agreement", Href: "/data_usage_agreements/renew_agreement/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "DataUsageAgreement", DataUsageAgreementShowData{AggregateName: "DataUsageAgreement", BackHref: "/data_usage_agreements", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type DeploymentShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type DeploymentShowData struct { AggregateName string; Id string; BackHref string; Fields []DeploymentShowField; Buttons []DeploymentButton }
	mux.HandleFunc("GET /deployments/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DeploymentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []DeploymentShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Environment", Value: fmt.Sprintf("%v", obj.Environment)},
			{Label: "Endpoint", Value: fmt.Sprintf("%v", obj.Endpoint)},
			{Label: "Purpose", Value: fmt.Sprintf("%v", obj.Purpose)},
			{Label: "Audience", Value: fmt.Sprintf("%v", obj.Audience)},
			{Label: "Deployed At", Value: fmt.Sprintf("%v", obj.DeployedAt)},
			{Label: "Decommissioned At", Value: fmt.Sprintf("%v", obj.DecommissionedAt)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Plan Deployment → planned", "Deploy Model → deployed", "Decommission Deployment → decommissioned"}},
		}
		buttons := []DeploymentButton{DeploymentButton{Label: "Deploy Model", Href: "/deployments/deploy_model", Allowed: true, Direct: true, IdField: "deployment_id"}, DeploymentButton{Label: "Decommission Deployment", Href: "/deployments/decommission_deployment", Allowed: true, Direct: true, IdField: "deployment_id"}}
		renderer.Render(w, "show", "Deployment", DeploymentShowData{AggregateName: "Deployment", BackHref: "/deployments", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type IncidentShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type IncidentShowData struct { AggregateName string; Id string; BackHref string; Fields []IncidentShowField; Buttons []IncidentButton }
	mux.HandleFunc("GET /incidents/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.IncidentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []IncidentShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Severity", Value: fmt.Sprintf("%v", obj.Severity)},
			{Label: "Category", Value: fmt.Sprintf("%v", obj.Category)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Reported By Id", Value: fmt.Sprintf("%v", obj.ReportedById)},
			{Label: "Reported At", Value: fmt.Sprintf("%v", obj.ReportedAt)},
			{Label: "Resolved At", Value: fmt.Sprintf("%v", obj.ResolvedAt)},
			{Label: "Resolution", Value: fmt.Sprintf("%v", obj.Resolution)},
			{Label: "Root Cause", Value: fmt.Sprintf("%v", obj.RootCause)},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Report Incident → reported", "Investigate Incident → investigating", "Mitigate Incident → mitigating", "Resolve Incident → resolved", "Close Incident → closed"}},
		}
		buttons := []IncidentButton{IncidentButton{Label: "Investigate Incident", Href: "/incidents/investigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, IncidentButton{Label: "Mitigate Incident", Href: "/incidents/mitigate_incident", Allowed: true, Direct: true, IdField: "incident_id"}, IncidentButton{Label: "Resolve Incident", Href: "/incidents/resolve_incident/new?id=" + obj.ID, Allowed: true}, IncidentButton{Label: "Close Incident", Href: "/incidents/close_incident", Allowed: true, Direct: true, IdField: "incident_id"}}
		renderer.Render(w, "show", "Incident", IncidentShowData{AggregateName: "Incident", BackHref: "/incidents", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type MonitoringShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type MonitoringShowData struct { AggregateName string; Id string; BackHref string; Fields []MonitoringShowField; Buttons []MonitoringButton }
	mux.HandleFunc("GET /monitorings/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.MonitoringRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []MonitoringShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Deployment Id", Value: fmt.Sprintf("%v", obj.DeploymentId)},
			{Label: "Metric Name", Value: fmt.Sprintf("%v", obj.MetricName)},
			{Label: "Value", Value: fmt.Sprintf("%v", obj.Value)},
			{Label: "Threshold", Value: fmt.Sprintf("%v", obj.Threshold)},
			{Label: "Recorded At", Value: fmt.Sprintf("%v", obj.RecordedAt)},
		}
		buttons := []MonitoringButton{MonitoringButton{Label: "Set Threshold", Href: "/monitorings/set_threshold/new?id=" + obj.ID, Allowed: true}}
		renderer.Render(w, "show", "Monitoring", MonitoringShowData{AggregateName: "Monitoring", BackHref: "/monitorings", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	type AssessmentShowField struct { Label string; Value string; Type string; Items []string; Transitions []string }
	type AssessmentShowData struct { AggregateName string; Id string; BackHref string; Fields []AssessmentShowField; Buttons []AssessmentButton }
	mux.HandleFunc("GET /assessments/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AssessmentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AssessmentShowField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Assessor Id", Value: fmt.Sprintf("%v", obj.AssessorId)},
			{Label: "Risk Level", Value: fmt.Sprintf("%v", obj.RiskLevel)},
			{Label: "Bias Score", Value: fmt.Sprintf("%v", obj.BiasScore)},
			{Label: "Safety Score", Value: fmt.Sprintf("%v", obj.SafetyScore)},
			{Label: "Transparency Score", Value: fmt.Sprintf("%v", obj.TransparencyScore)},
			{Label: "Overall Score", Value: fmt.Sprintf("%v", obj.OverallScore)},
			{Label: "Submitted At", Value: fmt.Sprintf("%v", obj.SubmittedAt)},
			{Label: "Findings", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Findings { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Mitigations", Type: "list", Items: func() []string { var s []string; for _, v := range obj.Mitigations { s = append(s, fmt.Sprintf("%v", v)) }; return s }()},
			{Label: "Status", Type: "lifecycle", Value: fmt.Sprintf("%v", obj.Status), Transitions: []string{"Initiate Assessment → pending", "Submit Assessment → submitted", "Reject Assessment → rejected"}},
		}
		buttons := []AssessmentButton{AssessmentButton{Label: "Record Finding", Href: "/assessments/record_finding/new?id=" + obj.ID, Allowed: true}, AssessmentButton{Label: "Submit Assessment", Href: "/assessments/submit_assessment/new?id=" + obj.ID, Allowed: true}, AssessmentButton{Label: "Reject Assessment", Href: "/assessments/reject_assessment", Allowed: true, Direct: true, IdField: "assessment_id"}}
		renderer.Render(w, "show", "Assessment", AssessmentShowData{AggregateName: "Assessment", BackHref: "/assessments", Id: obj.ID, Fields: fields, Buttons: buttons})
	})

	// Form routes (types in renderer.go)
	mux.HandleFunc("GET /governance_policys/create_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
			{Type: "select", Name: "category", Label: "Category", Required: true, Options: []FormOption{FormOption{Value: "regulatory", Label: "regulatory"}, FormOption{Value: "internal", Label: "internal"}, FormOption{Value: "ethical", Label: "ethical"}, FormOption{Value: "operational", Label: "operational"}}},
			// RegulatoryFramework dropdown built dynamically below
		}
		regulatoryframeworks, _ := app.RegulatoryFrameworkRepo.All()
		var regulatoryframeworkOpts []FormOption
		for _, item := range regulatoryframeworks {
			regulatoryframeworkOpts = append(regulatoryframeworkOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "framework_id", Label: "Framework", Required: true, Options: regulatoryframeworkOpts})
		renderer.Render(w, "form", "CreatePolicy", FormData{
			CommandName: "Create Policy",
			Action: "/governance_policys/create_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/activate_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "policy_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "ActivatePolicy", FormData{
			CommandName: "Activate Policy",
			Action: "/governance_policys/activate_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/suspend_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "policy_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "SuspendPolicy", FormData{
			CommandName: "Suspend Policy",
			Action: "/governance_policys/suspend_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/retire_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "policy_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RetirePolicy", FormData{
			CommandName: "Retire Policy",
			Action: "/governance_policys/retire_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/update_review_date/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "policy_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "review_date", Label: "Review Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "UpdateReviewDate", FormData{
			CommandName: "Update Review Date",
			Action: "/governance_policys/update_review_date",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /regulatory_frameworks/register_framework/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "jurisdiction", Label: "Jurisdiction", InputType: "text", Required: true},
			{Type: "input", Name: "version", Label: "Version", InputType: "text", Required: true},
			{Type: "input", Name: "authority", Label: "Authority", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RegisterFramework", FormData{
			CommandName: "Register Framework",
			Action: "/regulatory_frameworks/register_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /regulatory_frameworks/activate_framework/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "framework_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "ActivateFramework", FormData{
			CommandName: "Activate Framework",
			Action: "/regulatory_frameworks/activate_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /regulatory_frameworks/retire_framework/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "framework_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RetireFramework", FormData{
			CommandName: "Retire Framework",
			Action: "/regulatory_frameworks/retire_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/open_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			// GovernancePolicy dropdown built dynamically below
			// Stakeholder dropdown built dynamically below
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		governancepolicys, _ := app.GovernancePolicyRepo.All()
		var governancepolicyOpts []FormOption
		for _, item := range governancepolicys {
			governancepolicyOpts = append(governancepolicyOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "policy_id", Label: "Policy", Required: true, Options: governancepolicyOpts})
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "reviewer_id", Label: "Reviewer", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "OpenReview", FormData{
			CommandName: "Open Review",
			Action: "/compliance_reviews/open_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/approve_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "review_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ApproveReview", FormData{
			CommandName: "Approve Review",
			Action: "/compliance_reviews/approve_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/reject_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "review_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RejectReview", FormData{
			CommandName: "Reject Review",
			Action: "/compliance_reviews/reject_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/request_changes/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "review_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RequestChanges", FormData{
			CommandName: "Request Changes",
			Action: "/compliance_reviews/request_changes",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/request_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			// GovernancePolicy dropdown built dynamically below
			{Type: "input", Name: "requirement", Label: "Requirement", InputType: "text", Required: true},
			{Type: "input", Name: "reason", Label: "Reason", InputType: "text", Required: true},
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		governancepolicys, _ := app.GovernancePolicyRepo.All()
		var governancepolicyOpts []FormOption
		for _, item := range governancepolicys {
			governancepolicyOpts = append(governancepolicyOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "policy_id", Label: "Policy", Required: true, Options: governancepolicyOpts})
		renderer.Render(w, "form", "RequestExemption", FormData{
			CommandName: "Request Exemption",
			Action: "/exemptions/request_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/approve_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "exemption_id", Value: r.URL.Query().Get("id")},
			// Stakeholder dropdown built dynamically below
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "date", Required: true},
		}
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "approved_by_id", Label: "Approved By", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "ApproveExemption", FormData{
			CommandName: "Approve Exemption",
			Action: "/exemptions/approve_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/revoke_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "exemption_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RevokeExemption", FormData{
			CommandName: "Revoke Exemption",
			Action: "/exemptions/revoke_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/assign_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// Stakeholder dropdown built dynamically below
			// GovernancePolicy dropdown built dynamically below
		}
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "stakeholder_id", Label: "Stakeholder", Required: true, Options: stakeholderOpts})
		governancepolicys, _ := app.GovernancePolicyRepo.All()
		var governancepolicyOpts []FormOption
		for _, item := range governancepolicys {
			governancepolicyOpts = append(governancepolicyOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "policy_id", Label: "Policy", Required: true, Options: governancepolicyOpts})
		renderer.Render(w, "form", "AssignTraining", FormData{
			CommandName: "Assign Training",
			Action: "/training_records/assign_training",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/complete_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "training_record_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "certification", Label: "Certification", InputType: "text", Required: true},
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "CompleteTraining", FormData{
			CommandName: "Complete Training",
			Action: "/training_records/complete_training",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/renew_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "training_record_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "certification", Label: "Certification", InputType: "text", Required: true},
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "RenewTraining", FormData{
			CommandName: "Renew Training",
			Action: "/training_records/renew_training",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /stakeholders/register_stakeholder/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "email", Label: "Email", InputType: "text", Required: true},
			{Type: "select", Name: "role", Label: "Role", Required: true, Options: []FormOption{FormOption{Value: "assessor", Label: "assessor"}, FormOption{Value: "reviewer", Label: "reviewer"}, FormOption{Value: "governance_board", Label: "governance_board"}, FormOption{Value: "data_steward", Label: "data_steward"}, FormOption{Value: "incident_reporter", Label: "incident_reporter"}, FormOption{Value: "admin", Label: "admin"}, FormOption{Value: "auditor", Label: "auditor"}}},
			{Type: "input", Name: "team", Label: "Team", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RegisterStakeholder", FormData{
			CommandName: "Register Stakeholder",
			Action: "/stakeholders/register_stakeholder",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /stakeholders/assign_role/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "stakeholder_id", Value: r.URL.Query().Get("id")},
			{Type: "select", Name: "role", Label: "Role", Required: true, Options: []FormOption{FormOption{Value: "assessor", Label: "assessor"}, FormOption{Value: "reviewer", Label: "reviewer"}, FormOption{Value: "governance_board", Label: "governance_board"}, FormOption{Value: "data_steward", Label: "data_steward"}, FormOption{Value: "incident_reporter", Label: "incident_reporter"}, FormOption{Value: "admin", Label: "admin"}, FormOption{Value: "auditor", Label: "auditor"}}},
		}
		renderer.Render(w, "form", "AssignRole", FormData{
			CommandName: "Assign Role",
			Action: "/stakeholders/assign_role",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /stakeholders/deactivate_stakeholder/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "stakeholder_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DeactivateStakeholder", FormData{
			CommandName: "Deactivate Stakeholder",
			Action: "/stakeholders/deactivate_stakeholder",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /audit_logs/record_entry/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "entity_type", Label: "Entity Type", InputType: "text", Required: true},
			{Type: "input", Name: "entity_id", Label: "Entity Id", InputType: "text", Required: true},
			{Type: "input", Name: "action", Label: "Action", InputType: "text", Required: true},
			// Stakeholder dropdown built dynamically below
			{Type: "input", Name: "details", Label: "Details", InputType: "text", Required: true},
		}
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "actor_id", Label: "Actor", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "RecordEntry", FormData{
			CommandName: "Record Entry",
			Action: "/audit_logs/record_entry",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/register_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "version", Label: "Version", InputType: "text", Required: true},
			// Vendor dropdown built dynamically below
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		vendors, _ := app.VendorRepo.All()
		var vendorOpts []FormOption
		for _, item := range vendors {
			vendorOpts = append(vendorOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "provider_id", Label: "Provider", Required: true, Options: vendorOpts})
		renderer.Render(w, "form", "RegisterModel", FormData{
			CommandName: "Register Model",
			Action: "/ai_models/register_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/derive_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "version", Label: "Version", InputType: "text", Required: true},
			// AiModel dropdown built dynamically below
			{Type: "select", Name: "derivation_type", Label: "Derivation Type", Required: true, Options: []FormOption{FormOption{Value: "fine-tuned", Label: "fine-tuned"}, FormOption{Value: "distilled", Label: "distilled"}, FormOption{Value: "retrained", Label: "retrained"}, FormOption{Value: "quantized", Label: "quantized"}}},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "parent_model_id", Label: "Parent Model", Required: true, Options: aimodelOpts})
		renderer.Render(w, "form", "DeriveModel", FormData{
			CommandName: "Derive Model",
			Action: "/ai_models/derive_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/classify_risk/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "model_id", Value: r.URL.Query().Get("id")},
			{Type: "select", Name: "risk_level", Label: "Risk Level", Required: true, Options: []FormOption{FormOption{Value: "low", Label: "low"}, FormOption{Value: "medium", Label: "medium"}, FormOption{Value: "high", Label: "high"}, FormOption{Value: "critical", Label: "critical"}}},
		}
		renderer.Render(w, "form", "ClassifyRisk", FormData{
			CommandName: "Classify Risk",
			Action: "/ai_models/classify_risk",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/approve_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "model_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "ApproveModel", FormData{
			CommandName: "Approve Model",
			Action: "/ai_models/approve_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/suspend_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "model_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "SuspendModel", FormData{
			CommandName: "Suspend Model",
			Action: "/ai_models/suspend_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/retire_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "model_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RetireModel", FormData{
			CommandName: "Retire Model",
			Action: "/ai_models/retire_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/register_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "contact_email", Label: "Contact Email", InputType: "text", Required: true},
			{Type: "select", Name: "risk_tier", Label: "Risk Tier", Required: true, Options: []FormOption{FormOption{Value: "low", Label: "low"}, FormOption{Value: "medium", Label: "medium"}, FormOption{Value: "high", Label: "high"}}},
		}
		renderer.Render(w, "form", "RegisterVendor", FormData{
			CommandName: "Register Vendor",
			Action: "/vendors/register_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/approve_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "vendor_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "assessment_date", Label: "Assessment Date", InputType: "date", Required: true},
			{Type: "input", Name: "next_review_date", Label: "Next Review Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "ApproveVendor", FormData{
			CommandName: "Approve Vendor",
			Action: "/vendors/approve_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/suspend_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "vendor_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "SuspendVendor", FormData{
			CommandName: "Suspend Vendor",
			Action: "/vendors/suspend_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/create_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			{Type: "input", Name: "data_source", Label: "Data Source", InputType: "text", Required: true},
			{Type: "input", Name: "purpose", Label: "Purpose", InputType: "text", Required: true},
			{Type: "select", Name: "consent_type", Label: "Consent Type", Required: true, Options: []FormOption{FormOption{Value: "public_domain", Label: "public_domain"}, FormOption{Value: "CC-BY-SA", Label: "CC-BY-SA"}, FormOption{Value: "licensed", Label: "licensed"}, FormOption{Value: "consent", Label: "consent"}, FormOption{Value: "opt-out", Label: "opt-out"}}},
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		renderer.Render(w, "form", "CreateAgreement", FormData{
			CommandName: "Create Agreement",
			Action: "/data_usage_agreements/create_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/activate_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "agreement_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "date", Required: true},
			{Type: "input", Name: "expiration_date", Label: "Expiration Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "ActivateAgreement", FormData{
			CommandName: "Activate Agreement",
			Action: "/data_usage_agreements/activate_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/revoke_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "agreement_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RevokeAgreement", FormData{
			CommandName: "Revoke Agreement",
			Action: "/data_usage_agreements/revoke_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/renew_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "agreement_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "expiration_date", Label: "Expiration Date", InputType: "date", Required: true},
		}
		renderer.Render(w, "form", "RenewAgreement", FormData{
			CommandName: "Renew Agreement",
			Action: "/data_usage_agreements/renew_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /deployments/plan_deployment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			{Type: "select", Name: "environment", Label: "Environment", Required: true, Options: []FormOption{FormOption{Value: "development", Label: "development"}, FormOption{Value: "staging", Label: "staging"}, FormOption{Value: "production", Label: "production"}}},
			{Type: "input", Name: "endpoint", Label: "Endpoint", InputType: "text", Required: true},
			{Type: "input", Name: "purpose", Label: "Purpose", InputType: "text", Required: true},
			{Type: "select", Name: "audience", Label: "Audience", Required: true, Options: []FormOption{FormOption{Value: "internal", Label: "internal"}, FormOption{Value: "customer-facing", Label: "customer-facing"}, FormOption{Value: "public", Label: "public"}}},
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		renderer.Render(w, "form", "PlanDeployment", FormData{
			CommandName: "Plan Deployment",
			Action: "/deployments/plan_deployment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /deployments/deploy_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "deployment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DeployModel", FormData{
			CommandName: "Deploy Model",
			Action: "/deployments/deploy_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /deployments/decommission_deployment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "deployment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "DecommissionDeployment", FormData{
			CommandName: "Decommission Deployment",
			Action: "/deployments/decommission_deployment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/report_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			{Type: "select", Name: "severity", Label: "Severity", Required: true, Options: []FormOption{FormOption{Value: "low", Label: "low"}, FormOption{Value: "medium", Label: "medium"}, FormOption{Value: "high", Label: "high"}, FormOption{Value: "critical", Label: "critical"}}},
			{Type: "select", Name: "category", Label: "Category", Required: true, Options: []FormOption{FormOption{Value: "bias", Label: "bias"}, FormOption{Value: "safety", Label: "safety"}, FormOption{Value: "privacy", Label: "privacy"}, FormOption{Value: "performance", Label: "performance"}, FormOption{Value: "other", Label: "other"}}},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
			// Stakeholder dropdown built dynamically below
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "reported_by_id", Label: "Reported By", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "ReportIncident", FormData{
			CommandName: "Report Incident",
			Action: "/incidents/report_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/investigate_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "InvestigateIncident", FormData{
			CommandName: "Investigate Incident",
			Action: "/incidents/investigate_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/mitigate_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "MitigateIncident", FormData{
			CommandName: "Mitigate Incident",
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
			CommandName: "Resolve Incident",
			Action: "/incidents/resolve_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /incidents/close_incident/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "incident_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "CloseIncident", FormData{
			CommandName: "Close Incident",
			Action: "/incidents/close_incident",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /monitorings/record_metric/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			// Deployment dropdown built dynamically below
			{Type: "input", Name: "metric_name", Label: "Metric Name", InputType: "text", Required: true},
			{Type: "input", Name: "value", Label: "Value", InputType: "number", Required: true, Step: true},
			{Type: "input", Name: "threshold", Label: "Threshold", InputType: "number", Required: true, Step: true},
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		deployments, _ := app.DeploymentRepo.All()
		var deploymentOpts []FormOption
		for _, item := range deployments {
			deploymentOpts = append(deploymentOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.ID), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "deployment_id", Label: "Deployment", Required: true, Options: deploymentOpts})
		renderer.Render(w, "form", "RecordMetric", FormData{
			CommandName: "Record Metric",
			Action: "/monitorings/record_metric",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /monitorings/set_threshold/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "monitoring_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "threshold", Label: "Threshold", InputType: "number", Required: true, Step: true},
		}
		renderer.Render(w, "form", "SetThreshold", FormData{
			CommandName: "Set Threshold",
			Action: "/monitorings/set_threshold",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/initiate_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// AiModel dropdown built dynamically below
			// Stakeholder dropdown built dynamically below
		}
		aimodels, _ := app.AiModelRepo.All()
		var aimodelOpts []FormOption
		for _, item := range aimodels {
			aimodelOpts = append(aimodelOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "model_id", Label: "Model", Required: true, Options: aimodelOpts})
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "assessor_id", Label: "Assessor", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "InitiateAssessment", FormData{
			CommandName: "Initiate Assessment",
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
			CommandName: "Record Finding",
			Action: "/assessments/record_finding",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/submit_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "assessment_id", Value: r.URL.Query().Get("id")},
			{Type: "select", Name: "risk_level", Label: "Risk Level", Required: true, Options: []FormOption{FormOption{Value: "low", Label: "low"}, FormOption{Value: "medium", Label: "medium"}, FormOption{Value: "high", Label: "high"}, FormOption{Value: "critical", Label: "critical"}}},
			{Type: "input", Name: "bias_score", Label: "Bias Score", InputType: "number", Required: true, Step: true},
			{Type: "input", Name: "safety_score", Label: "Safety Score", InputType: "number", Required: true, Step: true},
			{Type: "input", Name: "transparency_score", Label: "Transparency Score", InputType: "number", Required: true, Step: true},
			{Type: "input", Name: "overall_score", Label: "Overall Score", InputType: "number", Required: true, Step: true},
		}
		renderer.Render(w, "form", "SubmitAssessment", FormData{
			CommandName: "Submit Assessment",
			Action: "/assessments/submit_assessment",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /assessments/reject_assessment/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "assessment_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RejectAssessment", FormData{
			CommandName: "Reject Assessment",
			Action: "/assessments/reject_assessment",
			Fields: fields,
		})
	})

	mux.HandleFunc("POST /_reset", func(w http.ResponseWriter, r *http.Request) {
		app.GovernancePolicyRepo = memory.NewGovernancePolicyMemoryRepository()
		app.RegulatoryFrameworkRepo = memory.NewRegulatoryFrameworkMemoryRepository()
		app.ComplianceReviewRepo = memory.NewComplianceReviewMemoryRepository()
		app.ExemptionRepo = memory.NewExemptionMemoryRepository()
		app.TrainingRecordRepo = memory.NewTrainingRecordMemoryRepository()
		app.StakeholderRepo = memory.NewStakeholderMemoryRepository()
		app.AuditLogRepo = memory.NewAuditLogMemoryRepository()
		app.AiModelRepo = memory.NewAiModelMemoryRepository()
		app.VendorRepo = memory.NewVendorMemoryRepository()
		app.DataUsageAgreementRepo = memory.NewDataUsageAgreementMemoryRepository()
		app.DeploymentRepo = memory.NewDeploymentMemoryRepository()
		app.IncidentRepo = memory.NewIncidentMemoryRepository()
		app.MonitoringRepo = memory.NewMonitoringMemoryRepository()
		app.AssessmentRepo = memory.NewAssessmentMemoryRepository()
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

	mux.HandleFunc("GET /governance_policys/queries/by_category", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.GovernancePolicyByCategory(app.GovernancePolicyRepo, r.URL.Query().Get("category"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /governance_policys/queries/by_framework", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.GovernancePolicyByFramework(app.GovernancePolicyRepo, r.URL.Query().Get("framework_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /governance_policys/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.GovernancePolicyActive(app.GovernancePolicyRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /regulatory_frameworks/queries/by_jurisdiction", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.RegulatoryFrameworkByJurisdiction(app.RegulatoryFrameworkRepo, r.URL.Query().Get("jurisdiction"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /regulatory_frameworks/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.RegulatoryFrameworkActive(app.RegulatoryFrameworkRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /compliance_reviews/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.ComplianceReviewByModel(app.ComplianceReviewRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /compliance_reviews/queries/pending", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.ComplianceReviewPending(app.ComplianceReviewRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /compliance_reviews/queries/by_reviewer", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.ComplianceReviewByReviewer(app.ComplianceReviewRepo, r.URL.Query().Get("reviewer_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /exemptions/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.ExemptionByModel(app.ExemptionRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /exemptions/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.ExemptionActive(app.ExemptionRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /exemptions/specifications/expired", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.ExemptionRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.ExemptionExpired{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "Expired", "satisfied": result})
	})

	mux.HandleFunc("GET /training_records/queries/by_stakeholder", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.TrainingRecordByStakeholder(app.TrainingRecordRepo, r.URL.Query().Get("stakeholder_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /training_records/queries/by_policy", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.TrainingRecordByPolicy(app.TrainingRecordRepo, r.URL.Query().Get("policy_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /training_records/queries/incomplete", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.TrainingRecordIncomplete(app.TrainingRecordRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /training_records/specifications/expired", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.TrainingRecordRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.TrainingRecordExpired{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "Expired", "satisfied": result})
	})

	mux.HandleFunc("GET /stakeholders/queries/by_role", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.StakeholderByRole(app.StakeholderRepo, r.URL.Query().Get("role"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /stakeholders/queries/by_team", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.StakeholderByTeam(app.StakeholderRepo, r.URL.Query().Get("team"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /stakeholders/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.StakeholderActive(app.StakeholderRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /audit_logs/queries/by_entity", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AuditLogByEntity(app.AuditLogRepo, r.URL.Query().Get("entity_type"), r.URL.Query().Get("entity_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /audit_logs/queries/by_actor", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AuditLogByActor(app.AuditLogRepo, r.URL.Query().Get("actor_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /ai_models/queries/by_provider", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AiModelByProvider(app.AiModelRepo, r.URL.Query().Get("provider_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /ai_models/queries/by_risk_level", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AiModelByRiskLevel(app.AiModelRepo, r.URL.Query().Get("level"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /ai_models/queries/by_status", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AiModelByStatus(app.AiModelRepo, r.URL.Query().Get("status"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /ai_models/queries/by_parent", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AiModelByParent(app.AiModelRepo, r.URL.Query().Get("parent_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /ai_models/specifications/high_risk", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AiModelRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.AiModelHighRisk{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "HighRisk", "satisfied": result})
	})

	mux.HandleFunc("GET /vendors/queries/by_risk_tier", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.VendorByRiskTier(app.VendorRepo, r.URL.Query().Get("tier"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /vendors/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.VendorActive(app.VendorRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /data_usage_agreements/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.DataUsageAgreementByModel(app.DataUsageAgreementRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /data_usage_agreements/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.DataUsageAgreementActive(app.DataUsageAgreementRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /data_usage_agreements/specifications/expired", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DataUsageAgreementRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.DataUsageAgreementExpired{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "Expired", "satisfied": result})
	})

	mux.HandleFunc("GET /deployments/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.DeploymentByModel(app.DeploymentRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /deployments/queries/by_environment", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.DeploymentByEnvironment(app.DeploymentRepo, r.URL.Query().Get("env"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /deployments/queries/active", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.DeploymentActive(app.DeploymentRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /deployments/specifications/customer_facing", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DeploymentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.DeploymentCustomerFacing{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "CustomerFacing", "satisfied": result})
	})

	mux.HandleFunc("GET /incidents/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.IncidentByModel(app.IncidentRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /incidents/queries/by_severity", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.IncidentBySeverity(app.IncidentRepo, r.URL.Query().Get("severity"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /incidents/queries/open", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.IncidentOpen(app.IncidentRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /incidents/specifications/critical", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.IncidentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.IncidentCritical{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "Critical", "satisfied": result})
	})

	mux.HandleFunc("GET /monitorings/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.MonitoringByModel(app.MonitoringRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /monitorings/queries/by_deployment", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.MonitoringByDeployment(app.MonitoringRepo, r.URL.Query().Get("deployment_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /monitorings/specifications/threshold_breached", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.MonitoringRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.MonitoringThresholdBreached{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "ThresholdBreached", "satisfied": result})
	})

	mux.HandleFunc("GET /assessments/queries/by_model", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AssessmentByModel(app.AssessmentRepo, r.URL.Query().Get("model_id"))
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /assessments/queries/pending", func(w http.ResponseWriter, r *http.Request) {
		results, _ := domain.AssessmentPending(app.AssessmentRepo)
		jsonResponse(w, results)
	})

	mux.HandleFunc("GET /assessments/specifications/critical_findings", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AssessmentRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, `{"error":"not found"}`, 404); return }
		spec := domain.AssessmentCriticalFindings{}
		result := spec.SatisfiedBy(obj)
		jsonResponse(w, map[string]interface{}{"specification": "CriticalFindings", "satisfied": result})
	})

	mux.HandleFunc("GET /_views/model_dashboard", func(w http.ResponseWriter, r *http.Request) {
		state, ok := app.ViewStates["ModelDashboard"]
		if !ok { state = map[string]interface{}{} }
		jsonResponse(w, state)
	})

	mux.HandleFunc("POST /_workflows/model_approval", func(w http.ResponseWriter, r *http.Request) {
		var attrs map[string]interface{}
		json.NewDecoder(r.Body).Decode(&attrs)
		jsonResponse(w, map[string]interface{}{"workflow": "ModelApproval", "status": "accepted", "attrs": attrs})
	})

	// Config
	type ConfigAgg struct { Name string; Href string; Count int; Commands string; Ports string }
	type ConfigData struct { Roles []string; CurrentRole string; Adapters []string; CurrentAdapter string; EventCount int; BootedAt string; Policies []string; Aggregates []ConfigAgg }
	currentRole := "admin"
	mux.HandleFunc("GET /config", func(w http.ResponseWriter, r *http.Request) {
		aggs := []ConfigAgg{
			{Name: "GovernancePolicy", Href: "/governance_policys", Commands: "CreatePolicy, ActivatePolicy, SuspendPolicy, RetirePolicy, UpdateReviewDate", Ports: "(none)"},
			{Name: "RegulatoryFramework", Href: "/regulatory_frameworks", Commands: "RegisterFramework, ActivateFramework, RetireFramework", Ports: "(none)"},
			{Name: "ComplianceReview", Href: "/compliance_reviews", Commands: "OpenReview, ApproveReview, RejectReview, RequestChanges", Ports: "(none)"},
			{Name: "Exemption", Href: "/exemptions", Commands: "RequestExemption, ApproveExemption, RevokeExemption", Ports: "(none)"},
			{Name: "TrainingRecord", Href: "/training_records", Commands: "AssignTraining, CompleteTraining, RenewTraining", Ports: "(none)"},
			{Name: "Stakeholder", Href: "/stakeholders", Commands: "RegisterStakeholder, AssignRole, DeactivateStakeholder", Ports: "(none)"},
			{Name: "AuditLog", Href: "/audit_logs", Commands: "RecordEntry", Ports: "(none)"},
			{Name: "AiModel", Href: "/ai_models", Commands: "RegisterModel, DeriveModel, ClassifyRisk, ApproveModel, SuspendModel, RetireModel", Ports: "(none)"},
			{Name: "Vendor", Href: "/vendors", Commands: "RegisterVendor, ApproveVendor, SuspendVendor", Ports: "(none)"},
			{Name: "DataUsageAgreement", Href: "/data_usage_agreements", Commands: "CreateAgreement, ActivateAgreement, RevokeAgreement, RenewAgreement", Ports: "(none)"},
			{Name: "Deployment", Href: "/deployments", Commands: "PlanDeployment, DeployModel, DecommissionDeployment", Ports: "(none)"},
			{Name: "Incident", Href: "/incidents", Commands: "ReportIncident, InvestigateIncident, MitigateIncident, ResolveIncident, CloseIncident", Ports: "(none)"},
			{Name: "Monitoring", Href: "/monitorings", Commands: "RecordMetric, SetThreshold", Ports: "(none)"},
			{Name: "Assessment", Href: "/assessments", Commands: "InitiateAssessment, RecordFinding, SubmitAssessment, RejectAssessment", Ports: "(none)"},
		}
		governancepolicyCount, _ := app.GovernancePolicyRepo.Count()
		aggs[0].Count = governancepolicyCount
		regulatoryframeworkCount, _ := app.RegulatoryFrameworkRepo.Count()
		aggs[1].Count = regulatoryframeworkCount
		compliancereviewCount, _ := app.ComplianceReviewRepo.Count()
		aggs[2].Count = compliancereviewCount
		exemptionCount, _ := app.ExemptionRepo.Count()
		aggs[3].Count = exemptionCount
		trainingrecordCount, _ := app.TrainingRecordRepo.Count()
		aggs[4].Count = trainingrecordCount
		stakeholderCount, _ := app.StakeholderRepo.Count()
		aggs[5].Count = stakeholderCount
		auditlogCount, _ := app.AuditLogRepo.Count()
		aggs[6].Count = auditlogCount
		aimodelCount, _ := app.AiModelRepo.Count()
		aggs[7].Count = aimodelCount
		vendorCount, _ := app.VendorRepo.Count()
		aggs[8].Count = vendorCount
		datausageagreementCount, _ := app.DataUsageAgreementRepo.Count()
		aggs[9].Count = datausageagreementCount
		deploymentCount, _ := app.DeploymentRepo.Count()
		aggs[10].Count = deploymentCount
		incidentCount, _ := app.IncidentRepo.Count()
		aggs[11].Count = incidentCount
		monitoringCount, _ := app.MonitoringRepo.Count()
		aggs[12].Count = monitoringCount
		assessmentCount, _ := app.AssessmentRepo.Count()
		aggs[13].Count = assessmentCount
		renderer.Render(w, "config", "Config", ConfigData{
			Roles: []string{"admin"},
			CurrentRole: currentRole,
			Adapters: []string{"memory", "filesystem"},
			CurrentAdapter: "memory",
			EventCount: len(app.EventBus.Events()),
			BootedAt: "running",
			Policies: []string{"RegisteredModel → AuditModelRegistration", "SuspendedModel → AuditModelSuspension", "ReportedIncident → AuditIncidentReport", "SubmittedAssessment → ClassifyAfterAssessment", "RejectedReview → SuspendOnReject", "ReportedIncident → SuspendOnCriticalIncident"},
			Aggregates: aggs,
		})
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("GovernanceDomain on http://localhost%s\n", addr)
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
