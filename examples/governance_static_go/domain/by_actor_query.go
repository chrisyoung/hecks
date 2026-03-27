package domain

func ByActor(repo AuditLogRepository, actor_id string) ([]*AuditLog, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AuditLog
	for _, item := range all {
		if item.ActorId == actor_id {
			results = append(results, item)
		}
	}
	return results, nil
}
