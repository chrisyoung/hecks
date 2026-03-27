package domain

type AssessmentRepository interface {
	Find(id string) (*Assessment, error)
	Save(Assessment *Assessment) error
	All() ([]*Assessment, error)
	Delete(id string) error
	Count() (int, error)
}
