package domain

const (
	IncidentStatusReported = "reported"
	IncidentStatusInvestigating = "investigating"
	IncidentStatusMitigating = "mitigating"
	IncidentStatusResolved = "resolved"
	IncidentStatusClosed = "closed"
)

func (a *Incident) IsReported() bool { return a.Status == IncidentStatusReported }
func (a *Incident) IsInvestigating() bool { return a.Status == IncidentStatusInvestigating }
func (a *Incident) IsMitigating() bool { return a.Status == IncidentStatusMitigating }
func (a *Incident) IsResolved() bool { return a.Status == IncidentStatusResolved }
func (a *Incident) IsClosed() bool { return a.Status == IncidentStatusClosed }

func (a *Incident) ValidTransition(target string) bool {
	switch {
	case target == "reported": return true
	case target == "investigating" && (a.Status == "reported"): return true
	case target == "mitigating" && (a.Status == "investigating"): return true
	case target == "resolved" && (a.Status == "investigating" || a.Status == "mitigating"): return true
	case target == "closed" && (a.Status == "resolved"): return true
	default: return false
	}
}
