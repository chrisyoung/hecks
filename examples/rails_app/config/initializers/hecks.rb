Hecks.configure do
  domain "pizzas_domain"
  adapter :sql unless Rails.env.test?
  include_ad_hoc_queries  # Pizza.where(...).order(...).limit(...)
end
