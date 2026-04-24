-- Sample price list rows (same dimensions as InitializeDatabase.sql). Enables GET /api/payments/priceListItems with e.g. US + New + Month.
INSERT INTO payments.PriceListItems (Id, SubscriptionPeriodCode, CategoryCode, CountryCode, MoneyValue, MoneyCurrency, IsActive)
VALUES
    ('A1000000-0000-4000-8000-000000000001', 'Month', 'New', 'PL', 60, 'PLN', 1),
    ('A1000000-0000-4000-8000-000000000002', 'HalfYear', 'New', 'PL', 320, 'PLN', 1),
    ('A1000000-0000-4000-8000-000000000003', 'Month', 'New', 'US', 15, 'USD', 1),
    ('A1000000-0000-4000-8000-000000000004', 'HalfYear', 'New', 'US', 80, 'USD', 1),
    ('A1000000-0000-4000-8000-000000000005', 'Month', 'Renewal', 'PL', 60, 'PLN', 1),
    ('A1000000-0000-4000-8000-000000000006', 'HalfYear', 'Renewal', 'PL', 320, 'PLN', 1),
    ('A1000000-0000-4000-8000-000000000007', 'Month', 'Renewal', 'US', 15, 'USD', 1),
    ('A1000000-0000-4000-8000-000000000008', 'HalfYear', 'Renewal', 'US', 80, 'USD', 1);
