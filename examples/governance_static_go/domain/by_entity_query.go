package domain

func ByEntity(repo AuditLogRepository, entity_type string, entity_id string) ([]*AuditLog, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
