package domain

const (
	AssessmentStatusPending = "pending"
	AssessmentStatusSubmitted = "submitted"
	AssessmentStatusRejected = "rejected"
)

func (a *Assessment) IsPending() bool { return a.Status == AssessmentStatusPending }
func (a *Assessment) IsSubmitted() bool { return a.Status == AssessmentStatusSubmitted }
func (a *Assessment) IsRejected() bool { return a.Status == AssessmentStatusRejected }

func (a *Assessment) ValidTransition(target string) bool {
	switch {
	case target == "pending": return true
	case target == "submitted" && (a.Status == "pending"): return true
	case target == "rejected" && (a.Status == "pending" || a.Status == "submitted"): return true
	default: return false
	}
}
