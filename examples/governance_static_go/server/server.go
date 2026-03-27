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
	}
}

func (app *App) Start(port int) error {
	mux := http.NewServeMux()

	exe, _ := os.Executable()
	viewsDir := filepath.Join(filepath.Dir(exe), "..", "views")
	if _, err := os.Stat(viewsDir); err != nil { viewsDir = "views" }
	nav := []NavItem{
		{Label: "GovernancePolicys", Href: "/governance_policys", Group: "Compliance"},
		{Label: "RegulatoryFrameworks", Href: "/regulatory_frameworks", Group: "Compliance"},
		{Label: "ComplianceReviews", Href: "/compliance_reviews", Group: "Compliance"},
		{Label: "Exemptions", Href: "/exemptions", Group: "Compliance"},
		{Label: "TrainingRecords", Href: "/training_records", Group: "Compliance"},
		{Label: "Stakeholders", Href: "/stakeholders", Group: "Identity"},
		{Label: "AuditLogs", Href: "/audit_logs", Group: "Identity"},
		{Label: "AiModels", Href: "/ai_models", Group: "ModelRegistry"},
		{Label: "Vendors", Href: "/vendors", Group: "ModelRegistry"},
		{Label: "DataUsageAgreements", Href: "/data_usage_agreements", Group: "ModelRegistry"},
		{Label: "Deployments", Href: "/deployments", Group: "Operations"},
		{Label: "Incidents", Href: "/incidents", Group: "Operations"},
		{Label: "Monitorings", Href: "/monitorings", Group: "Operations"},
		{Label: "Assessments", Href: "/assessments", Group: "RiskAssessment"},
		{Label: "Config", Href: "/config", Group: "System"},
	}
	renderer := NewRenderer(viewsDir, "GovernanceDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int; Policies int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "GovernanceDomain", HomeData{
			DomainName: "GovernanceDomain", Aggregates: []HomeAgg{{Name: "GovernancePolicys", Href: "/governance_policys", Commands: 5, Attributes: 8, Policies: 0}, {Name: "RegulatoryFrameworks", Href: "/regulatory_frameworks", Commands: 3, Attributes: 7, Policies: 0}, {Name: "ComplianceReviews", Href: "/compliance_reviews", Commands: 4, Attributes: 8, Policies: 0}, {Name: "Exemptions", Href: "/exemptions", Commands: 3, Attributes: 8, Policies: 0}, {Name: "TrainingRecords", Href: "/training_records", Commands: 3, Attributes: 6, Policies: 0}, {Name: "Stakeholders", Href: "/stakeholders", Commands: 3, Attributes: 5, Policies: 0}, {Name: "AuditLogs", Href: "/audit_logs", Commands: 1, Attributes: 6, Policies: 3}, {Name: "AiModels", Href: "/ai_models", Commands: 6, Attributes: 11, Policies: 3}, {Name: "Vendors", Href: "/vendors", Commands: 3, Attributes: 7, Policies: 0}, {Name: "DataUsageAgreements", Href: "/data_usage_agreements", Commands: 4, Attributes: 8, Policies: 0}, {Name: "Deployments", Href: "/deployments", Commands: 3, Attributes: 8, Policies: 0}, {Name: "Incidents", Href: "/incidents", Commands: 5, Attributes: 10, Policies: 0}, {Name: "Monitorings", Href: "/monitorings", Commands: 2, Attributes: 6, Policies: 0}, {Name: "Assessments", Href: "/assessments", Commands: 4, Attributes: 11, Policies: 0}},
		})
	})

	type GovernancePolicyCol struct { Label string }
	type GovernancePolicyItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type GovernancePolicyBtn struct { Label string; Href string; Allowed bool }
	type GovernancePolicyIndexData struct { AggregateName string; Description string; Items []GovernancePolicyItem; Columns []GovernancePolicyCol; Buttons []GovernancePolicyBtn; RowActions []RowAction }
	mux.HandleFunc("GET /governance_policys", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.GovernancePolicyRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.GovernancePolicyRepo.All()
		var rows []GovernancePolicyItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, GovernancePolicyItem{ID: obj.ID, ShortID: sid, ShowHref: "/governance_policys/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.Category), fmt.Sprintf("%v", obj.FrameworkId), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.ReviewDate), fmt.Sprintf("%d items", len(obj.Requirements)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "GovernancePolicys", GovernancePolicyIndexData{AggregateName: "GovernancePolicy", Description: "Organizational policies governing AI model usage and compliance", Items: rows, Columns: []GovernancePolicyCol{{Label: "Name"}, {Label: "Description"}, {Label: "Category"}, {Label: "Framework Id"}, {Label: "Effective Date"}, {Label: "Review Date"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []GovernancePolicyBtn{{Label: "CreatePolicy", Href: "/governance_policys/create_policy/new", Allowed: true}, {Label: "ActivatePolicy", Href: "/governance_policys/activate_policy/new", Allowed: true}, {Label: "SuspendPolicy", Href: "/governance_policys/suspend_policy/new", Allowed: true}, {Label: "RetirePolicy", Href: "/governance_policys/retire_policy/new", Allowed: true}, {Label: "UpdateReviewDate", Href: "/governance_policys/update_review_date/new", Allowed: true}}})
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

	type RegulatoryFrameworkCol struct { Label string }
	type RegulatoryFrameworkItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type RegulatoryFrameworkBtn struct { Label string; Href string; Allowed bool }
	type RegulatoryFrameworkIndexData struct { AggregateName string; Description string; Items []RegulatoryFrameworkItem; Columns []RegulatoryFrameworkCol; Buttons []RegulatoryFrameworkBtn; RowActions []RowAction }
	mux.HandleFunc("GET /regulatory_frameworks", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.RegulatoryFrameworkRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.RegulatoryFrameworkRepo.All()
		var rows []RegulatoryFrameworkItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, RegulatoryFrameworkItem{ID: obj.ID, ShortID: sid, ShowHref: "/regulatory_frameworks/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Jurisdiction), fmt.Sprintf("%v", obj.Version), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.Authority), fmt.Sprintf("%d items", len(obj.Requirements)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "RegulatoryFrameworks", RegulatoryFrameworkIndexData{AggregateName: "RegulatoryFramework", Description: "External regulatory requirements and their articles", Items: rows, Columns: []RegulatoryFrameworkCol{{Label: "Name"}, {Label: "Jurisdiction"}, {Label: "Version"}, {Label: "Effective Date"}, {Label: "Authority"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []RegulatoryFrameworkBtn{{Label: "RegisterFramework", Href: "/regulatory_frameworks/register_framework/new", Allowed: true}, {Label: "ActivateFramework", Href: "/regulatory_frameworks/activate_framework/new", Allowed: true}, {Label: "RetireFramework", Href: "/regulatory_frameworks/retire_framework/new", Allowed: true}}})
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

	type ComplianceReviewCol struct { Label string }
	type ComplianceReviewItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type ComplianceReviewBtn struct { Label string; Href string; Allowed bool }
	type ComplianceReviewIndexData struct { AggregateName string; Description string; Items []ComplianceReviewItem; Columns []ComplianceReviewCol; Buttons []ComplianceReviewBtn; RowActions []RowAction }
	mux.HandleFunc("GET /compliance_reviews", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.ComplianceReviewRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.ComplianceReviewRepo.All()
		var rows []ComplianceReviewItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, ComplianceReviewItem{ID: obj.ID, ShortID: sid, ShowHref: "/compliance_reviews/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.ReviewerId), fmt.Sprintf("%v", obj.Outcome), fmt.Sprintf("%v", obj.Notes), fmt.Sprintf("%v", obj.CompletedAt), fmt.Sprintf("%d items", len(obj.Conditions)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "ComplianceReviews", ComplianceReviewIndexData{AggregateName: "ComplianceReview", Description: "Reviews of AI models against governance policies", Items: rows, Columns: []ComplianceReviewCol{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Reviewer Id"}, {Label: "Outcome"}, {Label: "Notes"}, {Label: "Completed At"}, {Label: "Conditions"}, {Label: "Status"}}, Buttons: []ComplianceReviewBtn{{Label: "OpenReview", Href: "/compliance_reviews/open_review/new", Allowed: true}, {Label: "ApproveReview", Href: "/compliance_reviews/approve_review/new", Allowed: true}, {Label: "RejectReview", Href: "/compliance_reviews/reject_review/new", Allowed: true}, {Label: "RequestChanges", Href: "/compliance_reviews/request_changes/new", Allowed: true}}})
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

	type ExemptionCol struct { Label string }
	type ExemptionItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type ExemptionBtn struct { Label string; Href string; Allowed bool }
	type ExemptionIndexData struct { AggregateName string; Description string; Items []ExemptionItem; Columns []ExemptionCol; Buttons []ExemptionBtn; RowActions []RowAction }
	mux.HandleFunc("GET /exemptions", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.ExemptionRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.ExemptionRepo.All()
		var rows []ExemptionItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, ExemptionItem{ID: obj.ID, ShortID: sid, ShowHref: "/exemptions/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.Requirement), fmt.Sprintf("%v", obj.Reason), fmt.Sprintf("%v", obj.ApprovedById), fmt.Sprintf("%v", obj.ApprovedAt), fmt.Sprintf("%v", obj.ExpiresAt), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Exemptions", ExemptionIndexData{AggregateName: "Exemption", Description: "Approved exceptions to policy requirements", Items: rows, Columns: []ExemptionCol{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Requirement"}, {Label: "Reason"}, {Label: "Approved By Id"}, {Label: "Approved At"}, {Label: "Expires At"}, {Label: "Status"}}, Buttons: []ExemptionBtn{{Label: "RequestExemption", Href: "/exemptions/request_exemption/new", Allowed: true}}})
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

	type TrainingRecordCol struct { Label string }
	type TrainingRecordItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type TrainingRecordBtn struct { Label string; Href string; Allowed bool }
	type TrainingRecordIndexData struct { AggregateName string; Description string; Items []TrainingRecordItem; Columns []TrainingRecordCol; Buttons []TrainingRecordBtn; RowActions []RowAction }
	mux.HandleFunc("GET /training_records", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.TrainingRecordRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.TrainingRecordRepo.All()
		var rows []TrainingRecordItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, TrainingRecordItem{ID: obj.ID, ShortID: sid, ShowHref: "/training_records/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.StakeholderId), fmt.Sprintf("%v", obj.PolicyId), fmt.Sprintf("%v", obj.CompletedAt), fmt.Sprintf("%v", obj.ExpiresAt), fmt.Sprintf("%v", obj.CertificationId), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "TrainingRecords", TrainingRecordIndexData{AggregateName: "TrainingRecord", Description: "Staff training completion and certification tracking", Items: rows, Columns: []TrainingRecordCol{{Label: "Stakeholder Id"}, {Label: "Policy Id"}, {Label: "Completed At"}, {Label: "Expires At"}, {Label: "Certification Id"}, {Label: "Status"}}, Buttons: []TrainingRecordBtn{{Label: "AssignTraining", Href: "/training_records/assign_training/new", Allowed: true}}})
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
			cmd.CertificationId = r.FormValue("certification_id")
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
			cmd.CertificationId = r.FormValue("certification_id")
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

	type StakeholderCol struct { Label string }
	type StakeholderItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type StakeholderBtn struct { Label string; Href string; Allowed bool }
	type StakeholderIndexData struct { AggregateName string; Description string; Items []StakeholderItem; Columns []StakeholderCol; Buttons []StakeholderBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "Stakeholders", StakeholderIndexData{AggregateName: "Stakeholder", Description: "Users, roles, and permissions for governance participants", Items: rows, Columns: []StakeholderCol{{Label: "Name"}, {Label: "Email"}, {Label: "Role"}, {Label: "Team"}, {Label: "Status"}}, Buttons: []StakeholderBtn{{Label: "RegisterStakeholder", Href: "/stakeholders/register_stakeholder/new", Allowed: true}}})
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
	type AuditLogItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type AuditLogBtn struct { Label string; Href string; Allowed bool }
	type AuditLogIndexData struct { AggregateName string; Description string; Items []AuditLogItem; Columns []AuditLogCol; Buttons []AuditLogBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "AuditLogs", AuditLogIndexData{AggregateName: "AuditLog", Description: "Immutable record of all actions across the governance system", Items: rows, Columns: []AuditLogCol{{Label: "Entity Type"}, {Label: "Entity Id"}, {Label: "Action"}, {Label: "Actor Id"}, {Label: "Details"}, {Label: "Timestamp"}}, Buttons: []AuditLogBtn{{Label: "RecordEntry", Href: "/audit_logs/record_entry/new", Allowed: true}}})
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

	type AiModelCol struct { Label string }
	type AiModelItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type AiModelBtn struct { Label string; Href string; Allowed bool }
	type AiModelIndexData struct { AggregateName string; Description string; Items []AiModelItem; Columns []AiModelCol; Buttons []AiModelBtn; RowActions []RowAction }
	mux.HandleFunc("GET /ai_models", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.AiModelRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.AiModelRepo.All()
		var rows []AiModelItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, AiModelItem{ID: obj.ID, ShortID: sid, ShowHref: "/ai_models/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.Version), fmt.Sprintf("%v", obj.ProviderId), fmt.Sprintf("%v", obj.Description), fmt.Sprintf("%v", obj.RiskLevel), fmt.Sprintf("%v", obj.RegisteredAt), fmt.Sprintf("%v", obj.ParentModelId), fmt.Sprintf("%v", obj.DerivationType), fmt.Sprintf("%d items", len(obj.Capabilities)), fmt.Sprintf("%d items", len(obj.IntendedUses)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "AiModels", AiModelIndexData{AggregateName: "AiModel", Description: "AI models registered for governance oversight", Items: rows, Columns: []AiModelCol{{Label: "Name"}, {Label: "Version"}, {Label: "Provider Id"}, {Label: "Description"}, {Label: "Risk Level"}, {Label: "Registered At"}, {Label: "Parent Model Id"}, {Label: "Derivation Type"}, {Label: "Capabilities"}, {Label: "Intended Uses"}, {Label: "Status"}}, Buttons: []AiModelBtn{{Label: "RegisterModel", Href: "/ai_models/register_model/new", Allowed: true}, {Label: "DeriveModel", Href: "/ai_models/derive_model/new", Allowed: true}, {Label: "ClassifyRisk", Href: "/ai_models/classify_risk/new", Allowed: true}, {Label: "ApproveModel", Href: "/ai_models/approve_model/new", Allowed: true}, {Label: "SuspendModel", Href: "/ai_models/suspend_model/new", Allowed: true}, {Label: "RetireModel", Href: "/ai_models/retire_model/new", Allowed: true}}})
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

	type VendorCol struct { Label string }
	type VendorItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type VendorBtn struct { Label string; Href string; Allowed bool }
	type VendorIndexData struct { AggregateName string; Description string; Items []VendorItem; Columns []VendorCol; Buttons []VendorBtn; RowActions []RowAction }
	mux.HandleFunc("GET /vendors", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.VendorRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.VendorRepo.All()
		var rows []VendorItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, VendorItem{ID: obj.ID, ShortID: sid, ShowHref: "/vendors/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.Name), fmt.Sprintf("%v", obj.ContactEmail), fmt.Sprintf("%v", obj.RiskTier), fmt.Sprintf("%v", obj.AssessmentDate), fmt.Sprintf("%v", obj.NextReviewDate), fmt.Sprintf("%v", obj.SlaTerms), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "Vendors", VendorIndexData{AggregateName: "Vendor", Description: "Third-party AI model providers and their risk assessments", Items: rows, Columns: []VendorCol{{Label: "Name"}, {Label: "Contact Email"}, {Label: "Risk Tier"}, {Label: "Assessment Date"}, {Label: "Next Review Date"}, {Label: "Sla Terms"}, {Label: "Status"}}, Buttons: []VendorBtn{{Label: "RegisterVendor", Href: "/vendors/register_vendor/new", Allowed: true}}})
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

	type DataUsageAgreementCol struct { Label string }
	type DataUsageAgreementItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type DataUsageAgreementBtn struct { Label string; Href string; Allowed bool }
	type DataUsageAgreementIndexData struct { AggregateName string; Description string; Items []DataUsageAgreementItem; Columns []DataUsageAgreementCol; Buttons []DataUsageAgreementBtn; RowActions []RowAction }
	mux.HandleFunc("GET /data_usage_agreements", func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("Accept") == "application/json" || r.URL.Query().Get("format") == "json" {
			items, _ := app.DataUsageAgreementRepo.All(); jsonResponse(w, items); return
		}
		items, _ := app.DataUsageAgreementRepo.All()
		var rows []DataUsageAgreementItem
		for _, obj := range items {
			sid := obj.ID; if len(sid)>8 { sid=sid[:8]+"..." }
			rows = append(rows, DataUsageAgreementItem{ID: obj.ID, ShortID: sid, ShowHref: "/data_usage_agreements/show?id="+obj.ID, Cells: []string{fmt.Sprintf("%v", obj.ModelId), fmt.Sprintf("%v", obj.DataSource), fmt.Sprintf("%v", obj.Purpose), fmt.Sprintf("%v", obj.ConsentType), fmt.Sprintf("%v", obj.EffectiveDate), fmt.Sprintf("%v", obj.ExpirationDate), fmt.Sprintf("%d items", len(obj.Restrictions)), fmt.Sprintf("%v", obj.Status)}})
		}
		renderer.Render(w, "index", "DataUsageAgreements", DataUsageAgreementIndexData{AggregateName: "DataUsageAgreement", Description: "Agreements governing data usage for model training and inference", Items: rows, Columns: []DataUsageAgreementCol{{Label: "Model Id"}, {Label: "Data Source"}, {Label: "Purpose"}, {Label: "Consent Type"}, {Label: "Effective Date"}, {Label: "Expiration Date"}, {Label: "Restrictions"}, {Label: "Status"}}, Buttons: []DataUsageAgreementBtn{{Label: "CreateAgreement", Href: "/data_usage_agreements/create_agreement/new", Allowed: true}, {Label: "ActivateAgreement", Href: "/data_usage_agreements/activate_agreement/new", Allowed: true}, {Label: "RevokeAgreement", Href: "/data_usage_agreements/revoke_agreement/new", Allowed: true}, {Label: "RenewAgreement", Href: "/data_usage_agreements/renew_agreement/new", Allowed: true}}})
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

	type DeploymentCol struct { Label string }
	type DeploymentItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type DeploymentBtn struct { Label string; Href string; Allowed bool }
	type DeploymentIndexData struct { AggregateName string; Description string; Items []DeploymentItem; Columns []DeploymentCol; Buttons []DeploymentBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "Deployments", DeploymentIndexData{AggregateName: "Deployment", Description: "AI model deployments across environments", Items: rows, Columns: []DeploymentCol{{Label: "Model Id"}, {Label: "Environment"}, {Label: "Endpoint"}, {Label: "Purpose"}, {Label: "Audience"}, {Label: "Deployed At"}, {Label: "Decommissioned At"}, {Label: "Status"}}, Buttons: []DeploymentBtn{{Label: "PlanDeployment", Href: "/deployments/plan_deployment/new", Allowed: true}}})
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
	type IncidentItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type IncidentBtn struct { Label string; Href string; Allowed bool }
	type IncidentIndexData struct { AggregateName string; Description string; Items []IncidentItem; Columns []IncidentCol; Buttons []IncidentBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "Incidents", IncidentIndexData{AggregateName: "Incident", Description: "AI-related incidents including bias, safety, and performance issues", Items: rows, Columns: []IncidentCol{{Label: "Model Id"}, {Label: "Severity"}, {Label: "Category"}, {Label: "Description"}, {Label: "Reported By Id"}, {Label: "Reported At"}, {Label: "Resolved At"}, {Label: "Resolution"}, {Label: "Root Cause"}, {Label: "Status"}}, Buttons: []IncidentBtn{{Label: "ReportIncident", Href: "/incidents/report_incident/new", Allowed: true}}})
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
	type MonitoringItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type MonitoringBtn struct { Label string; Href string; Allowed bool }
	type MonitoringIndexData struct { AggregateName string; Description string; Items []MonitoringItem; Columns []MonitoringCol; Buttons []MonitoringBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "Monitorings", MonitoringIndexData{AggregateName: "Monitoring", Description: "Performance and safety metrics for deployed models", Items: rows, Columns: []MonitoringCol{{Label: "Model Id"}, {Label: "Deployment Id"}, {Label: "Metric Name"}, {Label: "Value"}, {Label: "Threshold"}, {Label: "Recorded At"}}, Buttons: []MonitoringBtn{{Label: "RecordMetric", Href: "/monitorings/record_metric/new", Allowed: true}}})
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

	type AssessmentCol struct { Label string }
	type AssessmentItem struct { ID string; ShortID string; ShowHref string; Cells []string; RowActions []RowAction }
	type AssessmentBtn struct { Label string; Href string; Allowed bool }
	type AssessmentIndexData struct { AggregateName string; Description string; Items []AssessmentItem; Columns []AssessmentCol; Buttons []AssessmentBtn; RowActions []RowAction }
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
		renderer.Render(w, "index", "Assessments", AssessmentIndexData{AggregateName: "Assessment", Description: "Risk assessments evaluating AI model safety, bias, and transparency", Items: rows, Columns: []AssessmentCol{{Label: "Model Id"}, {Label: "Assessor Id"}, {Label: "Risk Level"}, {Label: "Bias Score"}, {Label: "Safety Score"}, {Label: "Transparency Score"}, {Label: "Overall Score"}, {Label: "Submitted At"}, {Label: "Findings"}, {Label: "Mitigations"}, {Label: "Status"}}, Buttons: []AssessmentBtn{{Label: "InitiateAssessment", Href: "/assessments/initiate_assessment/new", Allowed: true}}})
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

	type GovernancePolicyField struct { Label string; Value string }
	type GovernancePolicyShowItem struct { ID string; Fields []GovernancePolicyField }
	type GovernancePolicyShowData struct { AggregateName string; BackHref string; Item GovernancePolicyShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /governance_policys/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.GovernancePolicyRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []GovernancePolicyField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Category", Value: fmt.Sprintf("%v", obj.Category)},
			{Label: "Framework Id", Value: fmt.Sprintf("%v", obj.FrameworkId)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Review Date", Value: fmt.Sprintf("%v", obj.ReviewDate)},
			{Label: "Requirements", Value: fmt.Sprintf("%v", obj.Requirements)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "GovernancePolicy", GovernancePolicyShowData{AggregateName: "GovernancePolicy", BackHref: "/governance_policys", Item: GovernancePolicyShowItem{ID: obj.ID, Fields: fields}})
	})

	type RegulatoryFrameworkField struct { Label string; Value string }
	type RegulatoryFrameworkShowItem struct { ID string; Fields []RegulatoryFrameworkField }
	type RegulatoryFrameworkShowData struct { AggregateName string; BackHref string; Item RegulatoryFrameworkShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /regulatory_frameworks/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.RegulatoryFrameworkRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []RegulatoryFrameworkField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Jurisdiction", Value: fmt.Sprintf("%v", obj.Jurisdiction)},
			{Label: "Version", Value: fmt.Sprintf("%v", obj.Version)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Authority", Value: fmt.Sprintf("%v", obj.Authority)},
			{Label: "Requirements", Value: fmt.Sprintf("%v", obj.Requirements)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "RegulatoryFramework", RegulatoryFrameworkShowData{AggregateName: "RegulatoryFramework", BackHref: "/regulatory_frameworks", Item: RegulatoryFrameworkShowItem{ID: obj.ID, Fields: fields}})
	})

	type ComplianceReviewField struct { Label string; Value string }
	type ComplianceReviewShowItem struct { ID string; Fields []ComplianceReviewField }
	type ComplianceReviewShowData struct { AggregateName string; BackHref string; Item ComplianceReviewShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /compliance_reviews/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.ComplianceReviewRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []ComplianceReviewField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Reviewer Id", Value: fmt.Sprintf("%v", obj.ReviewerId)},
			{Label: "Outcome", Value: fmt.Sprintf("%v", obj.Outcome)},
			{Label: "Notes", Value: fmt.Sprintf("%v", obj.Notes)},
			{Label: "Completed At", Value: fmt.Sprintf("%v", obj.CompletedAt)},
			{Label: "Conditions", Value: fmt.Sprintf("%v", obj.Conditions)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "ComplianceReview", ComplianceReviewShowData{AggregateName: "ComplianceReview", BackHref: "/compliance_reviews", Item: ComplianceReviewShowItem{ID: obj.ID, Fields: fields}})
	})

	type ExemptionField struct { Label string; Value string }
	type ExemptionShowItem struct { ID string; Fields []ExemptionField }
	type ExemptionShowData struct { AggregateName string; BackHref string; Item ExemptionShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /exemptions/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.ExemptionRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []ExemptionField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Requirement", Value: fmt.Sprintf("%v", obj.Requirement)},
			{Label: "Reason", Value: fmt.Sprintf("%v", obj.Reason)},
			{Label: "Approved By Id", Value: fmt.Sprintf("%v", obj.ApprovedById)},
			{Label: "Approved At", Value: fmt.Sprintf("%v", obj.ApprovedAt)},
			{Label: "Expires At", Value: fmt.Sprintf("%v", obj.ExpiresAt)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Exemption", ExemptionShowData{AggregateName: "Exemption", BackHref: "/exemptions", Item: ExemptionShowItem{ID: obj.ID, Fields: fields}})
	})

	type TrainingRecordField struct { Label string; Value string }
	type TrainingRecordShowItem struct { ID string; Fields []TrainingRecordField }
	type TrainingRecordShowData struct { AggregateName string; BackHref string; Item TrainingRecordShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /training_records/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.TrainingRecordRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []TrainingRecordField{
			{Label: "Stakeholder Id", Value: fmt.Sprintf("%v", obj.StakeholderId)},
			{Label: "Policy Id", Value: fmt.Sprintf("%v", obj.PolicyId)},
			{Label: "Completed At", Value: fmt.Sprintf("%v", obj.CompletedAt)},
			{Label: "Expires At", Value: fmt.Sprintf("%v", obj.ExpiresAt)},
			{Label: "Certification Id", Value: fmt.Sprintf("%v", obj.CertificationId)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "TrainingRecord", TrainingRecordShowData{AggregateName: "TrainingRecord", BackHref: "/training_records", Item: TrainingRecordShowItem{ID: obj.ID, Fields: fields}})
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

	type AiModelField struct { Label string; Value string }
	type AiModelShowItem struct { ID string; Fields []AiModelField }
	type AiModelShowData struct { AggregateName string; BackHref string; Item AiModelShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /ai_models/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.AiModelRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []AiModelField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Version", Value: fmt.Sprintf("%v", obj.Version)},
			{Label: "Provider Id", Value: fmt.Sprintf("%v", obj.ProviderId)},
			{Label: "Description", Value: fmt.Sprintf("%v", obj.Description)},
			{Label: "Risk Level", Value: fmt.Sprintf("%v", obj.RiskLevel)},
			{Label: "Registered At", Value: fmt.Sprintf("%v", obj.RegisteredAt)},
			{Label: "Parent Model Id", Value: fmt.Sprintf("%v", obj.ParentModelId)},
			{Label: "Derivation Type", Value: fmt.Sprintf("%v", obj.DerivationType)},
			{Label: "Capabilities", Value: fmt.Sprintf("%v", obj.Capabilities)},
			{Label: "Intended Uses", Value: fmt.Sprintf("%v", obj.IntendedUses)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "AiModel", AiModelShowData{AggregateName: "AiModel", BackHref: "/ai_models", Item: AiModelShowItem{ID: obj.ID, Fields: fields}})
	})

	type VendorField struct { Label string; Value string }
	type VendorShowItem struct { ID string; Fields []VendorField }
	type VendorShowData struct { AggregateName string; BackHref string; Item VendorShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /vendors/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.VendorRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []VendorField{
			{Label: "Name", Value: fmt.Sprintf("%v", obj.Name)},
			{Label: "Contact Email", Value: fmt.Sprintf("%v", obj.ContactEmail)},
			{Label: "Risk Tier", Value: fmt.Sprintf("%v", obj.RiskTier)},
			{Label: "Assessment Date", Value: fmt.Sprintf("%v", obj.AssessmentDate)},
			{Label: "Next Review Date", Value: fmt.Sprintf("%v", obj.NextReviewDate)},
			{Label: "Sla Terms", Value: fmt.Sprintf("%v", obj.SlaTerms)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "Vendor", VendorShowData{AggregateName: "Vendor", BackHref: "/vendors", Item: VendorShowItem{ID: obj.ID, Fields: fields}})
	})

	type DataUsageAgreementField struct { Label string; Value string }
	type DataUsageAgreementShowItem struct { ID string; Fields []DataUsageAgreementField }
	type DataUsageAgreementShowData struct { AggregateName string; BackHref string; Item DataUsageAgreementShowItem; Buttons []struct{ Label string; Href string; Allowed bool } }
	mux.HandleFunc("GET /data_usage_agreements/show", func(w http.ResponseWriter, r *http.Request) {
		obj, _ := app.DataUsageAgreementRepo.Find(r.URL.Query().Get("id"))
		if obj == nil { http.Error(w, "Not found", 404); return }
		fields := []DataUsageAgreementField{
			{Label: "Model Id", Value: fmt.Sprintf("%v", obj.ModelId)},
			{Label: "Data Source", Value: fmt.Sprintf("%v", obj.DataSource)},
			{Label: "Purpose", Value: fmt.Sprintf("%v", obj.Purpose)},
			{Label: "Consent Type", Value: fmt.Sprintf("%v", obj.ConsentType)},
			{Label: "Effective Date", Value: fmt.Sprintf("%v", obj.EffectiveDate)},
			{Label: "Expiration Date", Value: fmt.Sprintf("%v", obj.ExpirationDate)},
			{Label: "Restrictions", Value: fmt.Sprintf("%v", obj.Restrictions)},
			{Label: "Status", Value: fmt.Sprintf("%v", obj.Status)},
		}
		renderer.Render(w, "show", "DataUsageAgreement", DataUsageAgreementShowData{AggregateName: "DataUsageAgreement", BackHref: "/data_usage_agreements", Item: DataUsageAgreementShowItem{ID: obj.ID, Fields: fields}})
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
	mux.HandleFunc("GET /governance_policys/create_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
			{Type: "input", Name: "category", Label: "Category", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "CreatePolicy", FormData{
			CommandName: "CreatePolicy",
			Action: "/governance_policys/create_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/activate_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ActivatePolicy", FormData{
			CommandName: "ActivatePolicy",
			Action: "/governance_policys/activate_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/suspend_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "SuspendPolicy", FormData{
			CommandName: "SuspendPolicy",
			Action: "/governance_policys/suspend_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/retire_policy/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "RetirePolicy", FormData{
			CommandName: "RetirePolicy",
			Action: "/governance_policys/retire_policy",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /governance_policys/update_review_date/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "review_date", Label: "Review Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "UpdateReviewDate", FormData{
			CommandName: "UpdateReviewDate",
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
			CommandName: "RegisterFramework",
			Action: "/regulatory_frameworks/register_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /regulatory_frameworks/activate_framework/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ActivateFramework", FormData{
			CommandName: "ActivateFramework",
			Action: "/regulatory_frameworks/activate_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /regulatory_frameworks/retire_framework/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "RetireFramework", FormData{
			CommandName: "RetireFramework",
			Action: "/regulatory_frameworks/retire_framework",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/open_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "OpenReview", FormData{
			CommandName: "OpenReview",
			Action: "/compliance_reviews/open_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/approve_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ApproveReview", FormData{
			CommandName: "ApproveReview",
			Action: "/compliance_reviews/approve_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/reject_review/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RejectReview", FormData{
			CommandName: "RejectReview",
			Action: "/compliance_reviews/reject_review",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /compliance_reviews/request_changes/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "notes", Label: "Notes", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RequestChanges", FormData{
			CommandName: "RequestChanges",
			Action: "/compliance_reviews/request_changes",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/request_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "requirement", Label: "Requirement", InputType: "text", Required: true},
			{Type: "input", Name: "reason", Label: "Reason", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RequestExemption", FormData{
			CommandName: "RequestExemption",
			Action: "/exemptions/request_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/approve_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "exemption_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ApproveExemption", FormData{
			CommandName: "ApproveExemption",
			Action: "/exemptions/approve_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /exemptions/revoke_exemption/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "exemption_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "RevokeExemption", FormData{
			CommandName: "RevokeExemption",
			Action: "/exemptions/revoke_exemption",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/assign_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			// Stakeholder dropdown built dynamically below
		}
		stakeholders, _ := app.StakeholderRepo.All()
		var stakeholderOpts []FormOption
		for _, item := range stakeholders {
			stakeholderOpts = append(stakeholderOpts, FormOption{Value: item.ID, Label: fmt.Sprintf("%v", item.Name), Selected: item.ID == r.URL.Query().Get("id")})
		}
		fields = append(fields, FormField{Type: "select", Name: "stakeholder_id", Label: "Stakeholder", Required: true, Options: stakeholderOpts})
		renderer.Render(w, "form", "AssignTraining", FormData{
			CommandName: "AssignTraining",
			Action: "/training_records/assign_training",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/complete_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "training_record_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "CompleteTraining", FormData{
			CommandName: "CompleteTraining",
			Action: "/training_records/complete_training",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /training_records/renew_training/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "training_record_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "expires_at", Label: "Expires At", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RenewTraining", FormData{
			CommandName: "RenewTraining",
			Action: "/training_records/renew_training",
			Fields: fields,
		})
	})

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

	mux.HandleFunc("GET /ai_models/register_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "version", Label: "Version", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RegisterModel", FormData{
			CommandName: "RegisterModel",
			Action: "/ai_models/register_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/derive_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "version", Label: "Version", InputType: "text", Required: true},
			{Type: "input", Name: "derivation_type", Label: "Derivation Type", InputType: "text", Required: true},
			{Type: "input", Name: "description", Label: "Description", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "DeriveModel", FormData{
			CommandName: "DeriveModel",
			Action: "/ai_models/derive_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/classify_risk/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "risk_level", Label: "Risk Level", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ClassifyRisk", FormData{
			CommandName: "ClassifyRisk",
			Action: "/ai_models/classify_risk",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/approve_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "ApproveModel", FormData{
			CommandName: "ApproveModel",
			Action: "/ai_models/approve_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/suspend_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "SuspendModel", FormData{
			CommandName: "SuspendModel",
			Action: "/ai_models/suspend_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /ai_models/retire_model/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "RetireModel", FormData{
			CommandName: "RetireModel",
			Action: "/ai_models/retire_model",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/register_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "name", Label: "Name", InputType: "text", Required: true},
			{Type: "input", Name: "contact_email", Label: "Contact Email", InputType: "text", Required: true},
			{Type: "input", Name: "risk_tier", Label: "Risk Tier", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RegisterVendor", FormData{
			CommandName: "RegisterVendor",
			Action: "/vendors/register_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/approve_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "vendor_id", Value: r.URL.Query().Get("id")},
			{Type: "input", Name: "assessment_date", Label: "Assessment Date", InputType: "text", Required: true},
			{Type: "input", Name: "next_review_date", Label: "Next Review Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ApproveVendor", FormData{
			CommandName: "ApproveVendor",
			Action: "/vendors/approve_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /vendors/suspend_vendor/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "hidden", Name: "vendor_id", Value: r.URL.Query().Get("id")},
		}
		renderer.Render(w, "form", "SuspendVendor", FormData{
			CommandName: "SuspendVendor",
			Action: "/vendors/suspend_vendor",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/create_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "data_source", Label: "Data Source", InputType: "text", Required: true},
			{Type: "input", Name: "purpose", Label: "Purpose", InputType: "text", Required: true},
			{Type: "input", Name: "consent_type", Label: "Consent Type", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "CreateAgreement", FormData{
			CommandName: "CreateAgreement",
			Action: "/data_usage_agreements/create_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/activate_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "effective_date", Label: "Effective Date", InputType: "text", Required: true},
			{Type: "input", Name: "expiration_date", Label: "Expiration Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "ActivateAgreement", FormData{
			CommandName: "ActivateAgreement",
			Action: "/data_usage_agreements/activate_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/revoke_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
		}
		renderer.Render(w, "form", "RevokeAgreement", FormData{
			CommandName: "RevokeAgreement",
			Action: "/data_usage_agreements/revoke_agreement",
			Fields: fields,
		})
	})

	mux.HandleFunc("GET /data_usage_agreements/renew_agreement/new", func(w http.ResponseWriter, r *http.Request) {
		fields := []FormField{
			{Type: "input", Name: "expiration_date", Label: "Expiration Date", InputType: "text", Required: true},
		}
		renderer.Render(w, "form", "RenewAgreement", FormData{
			CommandName: "RenewAgreement",
			Action: "/data_usage_agreements/renew_agreement",
			Fields: fields,
		})
	})

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
