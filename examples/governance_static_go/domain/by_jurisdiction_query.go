package domain

func ByJurisdiction(repo RegulatoryFrameworkRepository, jurisdiction string) ([]*RegulatoryFramework, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
