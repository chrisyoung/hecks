package domain

// SuspendOnReject reacts to RejectedReview
// and triggers SuspendModel

type SuspendOnReject struct {}

func (p SuspendOnReject) EventName() string { return "RejectedReview" }

func (p SuspendOnReject) Execute(event interface{}, AiModelRepo AiModelRepository) error {
	e, ok := event.(*RejectedReview)
	if !ok { return nil }
	cmd := SuspendModel{
		ModelId: e.ModelId,
	}
	_, _, err := cmd.Execute(AiModelRepo)
	return err
}
