package domain

func ByRiskTier(repo VendorRepository, tier string) ([]*Vendor, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	var results []*Vendor
	for _, item := range all {
		if item.RiskTier == tier {
			results = append(results, item)
		}
	}
	return results, nil
}
