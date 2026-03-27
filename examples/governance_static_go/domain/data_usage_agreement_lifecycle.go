package domain

const (
	DataUsageAgreementStatusDraft = "draft"
	DataUsageAgreementStatusActive = "active"
	DataUsageAgreementStatusRevoked = "revoked"
)

func (a *DataUsageAgreement) IsDraft() bool { return a.Status == DataUsageAgreementStatusDraft }
func (a *DataUsageAgreement) IsActive() bool { return a.Status == DataUsageAgreementStatusActive }
func (a *DataUsageAgreement) IsRevoked() bool { return a.Status == DataUsageAgreementStatusRevoked }

func (a *DataUsageAgreement) ValidTransition(target string) bool {
	switch {
	case target == "draft": return true
	case target == "active" && (a.Status == "draft"): return true
	case target == "revoked" && (a.Status == "active"): return true
	case target == "active" && (a.Status == "active" || a.Status == "revoked"): return true
	default: return false
	}
}
