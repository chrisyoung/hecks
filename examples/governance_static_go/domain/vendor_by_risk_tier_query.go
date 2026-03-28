package domain

func VendorByRiskTier(repo VendorRepository, tier string) ([]*Vendor, error) {
	all, err := repo.All()
	if err != nil { return nil, err }
	return all, nil
}
