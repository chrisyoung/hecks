package server

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
	"os"
	"path/filepath"
	"model_registry_domain/domain"
	"model_registry_domain/adapters/memory"
	"model_registry_domain/runtime"
)

type App struct {
	AiModelRepo domain.AiModelRepository
	VendorRepo domain.VendorRepository
	DataUsageAgreementRepo domain.DataUsageAgreementRepository
	EventBus *runtime.EventBus
	CommandBus *runtime.CommandBus
}

func NewApp() *App {
	eventBus := runtime.NewEventBus()
	return &App{
		AiModelRepo: memory.NewAiModelMemoryRepository(),
		VendorRepo: memory.NewVendorMemoryRepository(),
		DataUsageAgreementRepo: memory.NewDataUsageAgreementMemoryRepository(),
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
		{Label: "AiModels", Href: "/ai_models"},
		{Label: "Vendors", Href: "/vendors"},
		{Label: "DataUsageAgreements", Href: "/data_usage_agreements"},
		{Label: "Config", Href: "/config"},
	}
	renderer := NewRenderer(viewsDir, "ModelRegistryDomain", nav)

	type HomeAgg struct { Name string; Href string; Commands int; Attributes int }
	type HomeData struct { DomainName string; Aggregates []HomeAgg }
	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		renderer.Render(w, "home", "ModelRegistryDomain", HomeData{
			DomainName: "ModelRegistryDomain", Aggregates: []HomeAgg{{Name: "AiModels", Href: "/ai_models", Commands: 6, Attributes: 11}, {Name: "Vendors", Href: "/vendors", Commands: 3, Attributes: 7}, {Name: "DataUsageAgreements", Href: "/data_usage_agreements", Commands: 4, Attributes: 8}},
		})
	})

	type AiModelCol struct { Label string }
	type AiModelItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type AiModelBtn struct { Label string; Href string; Allowed bool }
	type AiModelIndexData struct { AggregateName string; Items []AiModelItem; Columns []AiModelCol; Buttons []AiModelBtn }
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
		renderer.Render(w, "index", "AiModels", AiModelIndexData{AggregateName: "AiModel", Items: rows, Columns: []AiModelCol{{Label: "Name"}, {Label: "Version"}, {Label: "Provider Id"}, {Label: "Description"}, {Label: "Risk Level"}, {Label: "Registered At"}, {Label: "Parent Model Id"}, {Label: "Derivation Type"}, {Label: "Capabilities"}, {Label: "Intended Uses"}, {Label: "Status"}}, Buttons: []AiModelBtn{{Label: "RegisterModel", Href: "/ai_models/register_model/new", Allowed: true}, {Label: "DeriveModel", Href: "/ai_models/derive_model/new", Allowed: true}, {Label: "ClassifyRisk", Href: "/ai_models/classify_risk/new", Allowed: true}, {Label: "ApproveModel", Href: "/ai_models/approve_model/new", Allowed: true}, {Label: "SuspendModel", Href: "/ai_models/suspend_model/new", Allowed: true}, {Label: "RetireModel", Href: "/ai_models/retire_model/new", Allowed: true}}})
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
	type VendorItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type VendorBtn struct { Label string; Href string; Allowed bool }
	type VendorIndexData struct { AggregateName string; Items []VendorItem; Columns []VendorCol; Buttons []VendorBtn }
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
		renderer.Render(w, "index", "Vendors", VendorIndexData{AggregateName: "Vendor", Items: rows, Columns: []VendorCol{{Label: "Name"}, {Label: "Contact Email"}, {Label: "Risk Tier"}, {Label: "Assessment Date"}, {Label: "Next Review Date"}, {Label: "Sla Terms"}, {Label: "Status"}}, Buttons: []VendorBtn{{Label: "RegisterVendor", Href: "/vendors/register_vendor/new", Allowed: true}}})
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
	type DataUsageAgreementItem struct { ID string; ShortID string; ShowHref string; Cells []string }
	type DataUsageAgreementBtn struct { Label string; Href string; Allowed bool }
	type DataUsageAgreementIndexData struct { AggregateName string; Items []DataUsageAgreementItem; Columns []DataUsageAgreementCol; Buttons []DataUsageAgreementBtn }
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
		renderer.Render(w, "index", "DataUsageAgreements", DataUsageAgreementIndexData{AggregateName: "DataUsageAgreement", Items: rows, Columns: []DataUsageAgreementCol{{Label: "Model Id"}, {Label: "Data Source"}, {Label: "Purpose"}, {Label: "Consent Type"}, {Label: "Effective Date"}, {Label: "Expiration Date"}, {Label: "Restrictions"}, {Label: "Status"}}, Buttons: []DataUsageAgreementBtn{{Label: "CreateAgreement", Href: "/data_usage_agreements/create_agreement/new", Allowed: true}, {Label: "ActivateAgreement", Href: "/data_usage_agreements/activate_agreement/new", Allowed: true}, {Label: "RevokeAgreement", Href: "/data_usage_agreements/revoke_agreement/new", Allowed: true}, {Label: "RenewAgreement", Href: "/data_usage_agreements/renew_agreement/new", Allowed: true}}})
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

	// Form routes (types in renderer.go)
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
			{Name: "AiModel", Href: "/ai_models", Commands: "RegisterModel, DeriveModel, ClassifyRisk, ApproveModel, SuspendModel, RetireModel", Ports: "(none)"},
			{Name: "Vendor", Href: "/vendors", Commands: "RegisterVendor, ApproveVendor, SuspendVendor", Ports: "(none)"},
			{Name: "DataUsageAgreement", Href: "/data_usage_agreements", Commands: "CreateAgreement, ActivateAgreement, RevokeAgreement, RenewAgreement", Ports: "(none)"},
		}
		aimodelCount, _ := app.AiModelRepo.Count()
		aggs[0].Count = aimodelCount
		vendorCount, _ := app.VendorRepo.Count()
		aggs[1].Count = vendorCount
		datausageagreementCount, _ := app.DataUsageAgreementRepo.Count()
		aggs[2].Count = datausageagreementCount
		renderer.Render(w, "config", "Config", ConfigData{
			Roles: []string{"admin"},
			CurrentRole: currentRole,
			Adapters: []string{"memory", "filesystem"},
			CurrentAdapter: "memory",
			EventCount: len(app.EventBus.Events()),
			BootedAt: "running",
			Policies: []string{"SubmittedAssessment → ClassifyAfterAssessment", "RejectedReview → SuspendOnReject", "ReportedIncident → SuspendOnCriticalIncident"},
			Aggregates: aggs,
		})
	})

	addr := fmt.Sprintf(":%d", port)
	fmt.Printf("ModelRegistryDomain on http://localhost%s\n", addr)
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
