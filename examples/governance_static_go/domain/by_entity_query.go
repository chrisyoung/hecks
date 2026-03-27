package domain

func ByEntity(repo AuditLogRepository, entity_type string, entity_id string) ([]*AuditLog, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*AuditLog
	for _, item := range all {
		if item.EntityType == entity_type && item.EntityId == entity_id {
			results = append(results, item)
		}
	}
	return results, nil
}
