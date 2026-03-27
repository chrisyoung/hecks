package domain

type AuditLogRepository interface {
	Find(id string) (*AuditLog, error)
	Save(AuditLog *AuditLog) error
	All() ([]*AuditLog, error)
	Delete(id string) error
	Count() (int, error)
}
