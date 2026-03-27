package domain

func ByActor(repo AuditLogRepository, actor_id string) ([]*AuditLog, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
