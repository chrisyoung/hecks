package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"os"
	"path/filepath"
	"compliance_domain/domain"
	"compliance_domain/adapters/memory"
	"compliance_domain/runtime"
)

type App struct {
	GovernancePolicyRepo domain.GovernancePolicyRepository
	RegulatoryFrameworkRepo domain.RegulatoryFrameworkRepository
	ComplianceReviewRepo domain.ComplianceReviewRepository
	ExemptionRepo domain.ExemptionRepository
	TrainingRecordRepo domain.TrainingRecordRepository
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
		{Label: "GovernancePolicys", Href: "/governance_policys"},
		{Label: "RegulatoryFrameworks", Href: "/regulatory_frameworks"},
		{Label: "ComplianceReviews", Href: "/compliance_reviews"},
		{Label: "Exemptions", Href: "/exemptions"},
		{Label: "TrainingRecords", Href: "/training_records"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "ComplianceDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "ComplianceDomain", HomeData{
			DomainName: "ComplianceDomain", Aggregates: []HomeAgg{{Name: "GovernancePolicys", Href: "/governance_policys", Commands: 5, Attributes: 8}, {Name: "RegulatoryFrameworks", Href: "/regulatory_frameworks", Commands: 3, Attributes: 7}, {Name: "ComplianceReviews", Href: "/compliance_reviews", Commands: 4, Attributes: 8}, {Name: "Exemptions", Href: "/exemptions", Commands: 3, Attributes: 8}, {Name: "TrainingRecords", Href: "/training_records", Commands: 3, Attributes: 6}},
		})
	})

	type GovernancePolicyCol struct { Label string }
	type GovernancePolicyItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type GovernancePolicyBtn struct { Label string; Href string; Allowed bool }
	type GovernancePolicyIndexData struct { AggregateName string; Items []GovernancePolicyItem; Columns []GovernancePolicyCol; Buttons []GovernancePolicyBtn }
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
		renderer.Render(w, "index", "GovernancePolicys", GovernancePolicyIndexData{AggregateName: "GovernancePolicy", Items: rows, Columns: []GovernancePolicyCol{{Label: "Name"}, {Label: "Description"}, {Label: "Category"}, {Label: "Framework Id"}, {Label: "Effective Date"}, {Label: "Review Date"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []GovernancePolicyBtn{{Label: "CreatePolicy", Href: "/governance_policys/create_policy/new", Allowed: true}, {Label: "ActivatePolicy", Href: "/governance_policys/activate_policy/new", Allowed: true}, {Label: "SuspendPolicy", Href: "/governance_policys/suspend_policy/new", Allowed: true}, {Label: "RetirePolicy", Href: "/governance_policys/retire_policy/new", Allowed: true}, {Label: "UpdateReviewDate", Href: "/governance_policys/update_review_date/new", Allowed: true}}})
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
	type RegulatoryFrameworkItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type RegulatoryFrameworkBtn struct { Label string; Href string; Allowed bool }
	type RegulatoryFrameworkIndexData struct { AggregateName string; Items []RegulatoryFrameworkItem; Columns []RegulatoryFrameworkCol; Buttons []RegulatoryFrameworkBtn }
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
		renderer.Render(w, "index", "RegulatoryFrameworks", RegulatoryFrameworkIndexData{AggregateName: "RegulatoryFramework", Items: rows, Columns: []RegulatoryFrameworkCol{{Label: "Name"}, {Label: "Jurisdiction"}, {Label: "Version"}, {Label: "Effective Date"}, {Label: "Authority"}, {Label: "Requirements"}, {Label: "Status"}}, Buttons: []RegulatoryFrameworkBtn{{Label: "RegisterFramework", Href: "/regulatory_frameworks/register_framework/new", Allowed: true}, {Label: "ActivateFramework", Href: "/regulatory_frameworks/activate_framework/new", Allowed: true}, {Label: "RetireFramework", Href: "/regulatory_frameworks/retire_framework/new", Allowed: true}}})
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
	type ComplianceReviewItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type ComplianceReviewBtn struct { Label string; Href string; Allowed bool }
	type ComplianceReviewIndexData struct { AggregateName string; Items []ComplianceReviewItem; Columns []ComplianceReviewCol; Buttons []ComplianceReviewBtn }
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
		renderer.Render(w, "index", "ComplianceReviews", ComplianceReviewIndexData{AggregateName: "ComplianceReview", Items: rows, Columns: []ComplianceReviewCol{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Reviewer Id"}, {Label: "Outcome"}, {Label: "Notes"}, {Label: "Completed At"}, {Label: "Conditions"}, {Label: "Status"}}, Buttons: []ComplianceReviewBtn{{Label: "OpenReview", Href: "/compliance_reviews/open_review/new", Allowed: true}, {Label: "ApproveReview", Href: "/compliance_reviews/approve_review/new", Allowed: true}, {Label: "RejectReview", Href: "/compliance_reviews/reject_review/new", Allowed: true}, {Label: "RequestChanges", Href: "/compliance_reviews/request_changes/new", Allowed: true}}})
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
	type ExemptionItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type ExemptionBtn struct { Label string; Href string; Allowed bool }
	type ExemptionIndexData struct { AggregateName string; Items []ExemptionItem; Columns []ExemptionCol; Buttons []ExemptionBtn }
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
		renderer.Render(w, "index", "Exemptions", ExemptionIndexData{AggregateName: "Exemption", Items: rows, Columns: []ExemptionCol{{Label: "Model Id"}, {Label: "Policy Id"}, {Label: "Requirement"}, {Label: "Reason"}, {Label: "Approved By Id"}, {Label: "Approved At"}, {Label: "Expires At"}, {Label: "Status"}}, Buttons: []ExemptionBtn{{Label: "RequestExemption", Href: "/exemptions/request_exemption/new", Allowed: true}}})
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
	type TrainingRecordItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type TrainingRecordBtn struct { Label string; Href string; Allowed bool }
	type TrainingRecordIndexData struct { AggregateName string; Items []TrainingRecordItem; Columns []TrainingRecordCol; Buttons []TrainingRecordBtn }
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
		renderer.Render(w, "index", "TrainingRecords", TrainingRecordIndexData{AggregateName: "TrainingRecord", Items: rows, Columns: []TrainingRecordCol{{Label: "Stakeholder Id"}, {Label: "Policy Id"}, {Label: "Completed At"}, {Label: "Expires At"}, {Label: "Certification Id"}, {Label: "Status"}}, Buttons: []TrainingRecordBtn{{Label: "AssignTraining", Href: "/training_records/assign_training/new", Allowed: true}}})
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
		}
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
	fmt.Printf("ComplianceDomain on http://localhost%s\n", addr)
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
