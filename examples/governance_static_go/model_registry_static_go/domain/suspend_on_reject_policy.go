package domain

// SuspendOnReject reacts to RejectedReview
// and triggers SuspendModel

type SuspendOnReject struct {}

func (p SuspendOnReject) EventName() string { return "RejectedReview" }

func (p SuspendOnReject) Execute(event interface{}) {
	// trigger aggregate not found for SuspendModel
}
