package domain

type TrainingRecordRepository interface {
	Find(id string) (*TrainingRecord, error)
	Save(TrainingRecord *TrainingRecord) error
	All() ([]*TrainingRecord, error)
	Delete(id string) error
	Count() (int, error)
}
