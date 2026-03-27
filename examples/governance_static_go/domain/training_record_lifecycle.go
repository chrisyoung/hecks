package domain

const (
	TrainingRecordStatusAssigned = "assigned"
	TrainingRecordStatusCompleted = "completed"
)

func (a *TrainingRecord) IsAssigned() bool { return a.Status == TrainingRecordStatusAssigned }
func (a *TrainingRecord) IsCompleted() bool { return a.Status == TrainingRecordStatusCompleted }

func (a *TrainingRecord) ValidTransition(target string) bool {
	switch {
	case target == "assigned": return true
	case target == "completed" && (a.Status == "assigned"): return true
	case target == "completed" && (a.Status == "completed"): return true
	default: return false
	}
}
