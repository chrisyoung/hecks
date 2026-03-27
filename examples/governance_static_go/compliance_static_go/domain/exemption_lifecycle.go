package domain

const (
	ExemptionStatusRequested = "requested"
	ExemptionStatusActive = "active"
	ExemptionStatusRevoked = "revoked"
)

func (a *Exemption) IsRequested() bool { return a.Status == ExemptionStatusRequested }
func (a *Exemption) IsActive() bool { return a.Status == ExemptionStatusActive }
func (a *Exemption) IsRevoked() bool { return a.Status == ExemptionStatusRevoked }

func (a *Exemption) ValidTransition(target string) bool {
	switch {
	case target == "requested": return true
	case target == "active" && (a.Status == "requested"): return true
	case target == "revoked" && (a.Status == "active"): return true
	default: return false
	}
}
