package domain

const (
	RegulatoryFrameworkStatusDraft = "draft"
	RegulatoryFrameworkStatusActive = "active"
	RegulatoryFrameworkStatusRetired = "retired"
)

func (a *RegulatoryFramework) IsDraft() bool { return a.Status == RegulatoryFrameworkStatusDraft }
func (a *RegulatoryFramework) IsActive() bool { return a.Status == RegulatoryFrameworkStatusActive }
func (a *RegulatoryFramework) IsRetired() bool { return a.Status == RegulatoryFrameworkStatusRetired }

func (a *RegulatoryFramework) ValidTransition(target string) bool {
	switch {
	case target == "draft": return true
	case target == "active" && (a.Status == "draft"): return true
	case target == "retired" && (a.Status == "active"): return true
	default: return false
	}
}
