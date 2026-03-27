package domain

const (
	DeploymentStatusPlanned = "planned"
	DeploymentStatusDeployed = "deployed"
	DeploymentStatusDecommissioned = "decommissioned"
)

func (a *Deployment) IsPlanned() bool { return a.Status == DeploymentStatusPlanned }
func (a *Deployment) IsDeployed() bool { return a.Status == DeploymentStatusDeployed }
func (a *Deployment) IsDecommissioned() bool { return a.Status == DeploymentStatusDecommissioned }

func (a *Deployment) ValidTransition(target string) bool {
	switch {
	case target == "planned": return true
	case target == "deployed" && (a.Status == "planned"): return true
	case target == "decommissioned" && (a.Status == "deployed"): return true
	default: return false
	}
}
