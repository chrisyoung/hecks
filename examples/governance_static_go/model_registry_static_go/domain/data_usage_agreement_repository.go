package domain

type DataUsageAgreementRepository interface {
	Find(id string) (*DataUsageAgreement, error)
	Save(DataUsageAgreement *DataUsageAgreement) error
	All() ([]*DataUsageAgreement, error)
	Delete(id string) error
	Count() (int, error)
}
