package domain

func ByJurisdiction(repo RegulatoryFrameworkRepository, jurisdiction string) ([]*RegulatoryFramework, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*RegulatoryFramework
	for _, item := range all {
		if item.Jurisdiction == jurisdiction {
			results = append(results, item)
		}
	}
	return results, nil
}
