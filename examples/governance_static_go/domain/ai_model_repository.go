package domain

type AiModelRepository interface {
	Find(id string) (*AiModel, error)
	Save(AiModel *AiModel) error
	All() ([]*AiModel, error)
	Delete(id string) error
	Count() (int, error)
}
