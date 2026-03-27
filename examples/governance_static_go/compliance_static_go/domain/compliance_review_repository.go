package domain

type ComplianceReviewRepository interface {
	Find(id string) (*ComplianceReview, error)
	Save(ComplianceReview *ComplianceReview) error
	All() ([]*ComplianceReview, error)
	Delete(id string) error
	Count() (int, error)
}
