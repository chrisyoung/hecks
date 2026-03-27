package domain

const (
	StakeholderStatusActive = "active"
	StakeholderStatusDeactivated = "deactivated"
)

func (a *Stakeholder) IsActive() bool { return a.Status == StakeholderStatusActive }
func (a *Stakeholder) IsDeactivated() bool { return a.Status == StakeholderStatusDeactivated }

func (a *Stakeholder) ValidTransition(target string) bool {
	switch {
	case target == "active": return true
	case target == "deactivated" && (a.Status == "active"): return true
	default: return false
	}
}
