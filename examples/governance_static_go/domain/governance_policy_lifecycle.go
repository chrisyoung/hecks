package domain

const (
	GovernancePolicyStatusDraft = "draft"
	GovernancePolicyStatusActive = "active"
	GovernancePolicyStatusSuspended = "suspended"
	GovernancePolicyStatusRetired = "retired"
)

func (a *GovernancePolicy) IsDraft() bool { return a.Status == GovernancePolicyStatusDraft }
func (a *GovernancePolicy) IsActive() bool { return a.Status == GovernancePolicyStatusActive }
func (a *GovernancePolicy) IsSuspended() bool { return a.Status == GovernancePolicyStatusSuspended }
func (a *GovernancePolicy) IsRetired() bool { return a.Status == GovernancePolicyStatusRetired }

func (a *GovernancePolicy) ValidTransition(target string) bool {
	switch {
	case target == "draft": return true
	case target == "active" && (a.Status == "draft"): return true
	case target == "suspended" && (a.Status == "active"): return true
	case target == "retired" && (a.Status == "active" || a.Status == "suspended"): return true
	default: return false
	}
}
