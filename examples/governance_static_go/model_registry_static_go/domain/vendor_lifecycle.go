package domain

const (
	VendorStatusPendingReview = "pending_review"
	VendorStatusApproved = "approved"
	VendorStatusSuspended = "suspended"
)

func (a *Vendor) IsPendingReview() bool { return a.Status == VendorStatusPendingReview }
func (a *Vendor) IsApproved() bool { return a.Status == VendorStatusApproved }
func (a *Vendor) IsSuspended() bool { return a.Status == VendorStatusSuspended }

func (a *Vendor) ValidTransition(target string) bool {
	switch {
	case target == "pending_review": return true
	case target == "approved" && (a.Status == "pending_review"): return true
	case target == "suspended" && (a.Status == "approved"): return true
	default: return false
	}
}
