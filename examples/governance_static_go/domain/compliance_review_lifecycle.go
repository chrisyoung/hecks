package domain

const (
	ComplianceReviewStatusOpen = "open"
	ComplianceReviewStatusApproved = "approved"
	ComplianceReviewStatusRejected = "rejected"
	ComplianceReviewStatusChangesRequested = "changes_requested"
)

func (a *ComplianceReview) IsOpen() bool { return a.Status == ComplianceReviewStatusOpen }
func (a *ComplianceReview) IsApproved() bool { return a.Status == ComplianceReviewStatusApproved }
func (a *ComplianceReview) IsRejected() bool { return a.Status == ComplianceReviewStatusRejected }
func (a *ComplianceReview) IsChangesRequested() bool { return a.Status == ComplianceReviewStatusChangesRequested }

func (a *ComplianceReview) ValidTransition(target string) bool {
	switch {
	case target == "open": return true
	case target == "approved" && (a.Status == "open" || a.Status == "changes_requested"): return true
	case target == "rejected" && (a.Status == "open" || a.Status == "changes_requested"): return true
	case target == "changes_requested" && (a.Status == "open"): return true
	default: return false
	}
}
