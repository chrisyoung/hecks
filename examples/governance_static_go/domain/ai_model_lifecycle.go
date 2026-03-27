package domain

const (
	AiModelStatusDraft = "draft"
	AiModelStatusClassified = "classified"
	AiModelStatusApproved = "approved"
	AiModelStatusSuspended = "suspended"
	AiModelStatusRetired = "retired"
)

func (a *AiModel) IsDraft() bool { return a.Status == AiModelStatusDraft }
func (a *AiModel) IsClassified() bool { return a.Status == AiModelStatusClassified }
func (a *AiModel) IsApproved() bool { return a.Status == AiModelStatusApproved }
func (a *AiModel) IsSuspended() bool { return a.Status == AiModelStatusSuspended }
func (a *AiModel) IsRetired() bool { return a.Status == AiModelStatusRetired }

func (a *AiModel) ValidTransition(target string) bool {
	switch {
	case target == "draft": return true
	case target == "draft": return true
	case target == "classified" && (a.Status == "draft"): return true
	case target == "approved" && (a.Status == "classified"): return true
	case target == "suspended" && (a.Status == "approved" || a.Status == "classified" || a.Status == "draft"): return true
	case target == "retired" && (a.Status == "approved" || a.Status == "suspended"): return true
	default: return false
	}
}
