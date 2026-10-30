-- EcoLoop UG initial relational schema (PostgreSQL).
-- Review and run only in a development database. Not yet integrated with the API.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- Enable PostGIS only where installed and permitted:
-- CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    phone TEXT UNIQUE,
    role TEXT NOT NULL CHECK (role IN ('household', 'collector', 'business', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS businesses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES profiles(id),
    name TEXT NOT NULL,
    business_type TEXT NOT NULL CHECK (business_type IN ('collector', 'recycler', 'industrial_buyer')),
    verification_status TEXT NOT NULL DEFAULT 'pending'
      CHECK (verification_status IN ('pending', 'verified', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS waste_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL DEFAULT '',
    unit TEXT NOT NULL DEFAULT 'kg'
);

CREATE TABLE IF NOT EXISTS waste_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    household_id UUID NOT NULL REFERENCES profiles(id),
    category_id UUID NOT NULL REFERENCES waste_categories(id),
    quantity_kg NUMERIC(12,3) NOT NULL CHECK (quantity_kg > 0),
    description TEXT NOT NULL DEFAULT '',
    location_label TEXT NOT NULL,
    latitude DOUBLE PRECISION CHECK (latitude BETWEEN -90 AND 90),
    longitude DOUBLE PRECISION CHECK (longitude BETWEEN -180 AND 180),
    status TEXT NOT NULL DEFAULT 'available'
      CHECK (status IN ('available', 'requested', 'collected', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS collection_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID NOT NULL REFERENCES waste_listings(id),
    collector_id UUID NOT NULL REFERENCES profiles(id),
    status TEXT NOT NULL DEFAULT 'assigned'
      CHECK (status IN ('assigned', 'scheduled', 'collected', 'completed', 'cancelled')),
    scheduled_at TIMESTAMPTZ,
    collected_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS material_listings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id),
    category_id UUID NOT NULL REFERENCES waste_categories(id),
    quantity_kg NUMERIC(12,3) NOT NULL CHECK (quantity_kg > 0),
    asking_price_ugx NUMERIC(14,2) CHECK (asking_price_ugx >= 0),
    availability_status TEXT NOT NULL DEFAULT 'available'
      CHECK (availability_status IN ('available', 'reserved', 'sold', 'withdrawn')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sourcing_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id),
    category_id UUID NOT NULL REFERENCES waste_categories(id),
    quantity_required_kg NUMERIC(12,3) NOT NULL CHECK (quantity_required_kg > 0),
    description TEXT NOT NULL DEFAULT '',
    status TEXT NOT NULL DEFAULT 'open'
      CHECK (status IN ('draft', 'open', 'reviewing', 'fulfilled', 'cancelled')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS education_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    difficulty TEXT NOT NULL DEFAULT 'beginner'
      CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),
    published BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS learning_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id),
    module_id UUID NOT NULL REFERENCES education_modules(id),
    score NUMERIC(5,2) CHECK (score BETWEEN 0 AND 100),
    completed_at TIMESTAMPTZ,
    UNIQUE (user_id, module_id)
);

CREATE TABLE IF NOT EXISTS material_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id UUID REFERENCES waste_listings(id),
    material_listing_id UUID REFERENCES material_listings(id),
    quantity_kg NUMERIC(12,3) NOT NULL CHECK (quantity_kg > 0),
    transaction_status TEXT NOT NULL DEFAULT 'pending'
      CHECK (transaction_status IN ('pending', 'delivered', 'accepted', 'rejected', 'cancelled')),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (listing_id IS NOT NULL OR material_listing_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_waste_listings_status ON waste_listings(status);
CREATE INDEX IF NOT EXISTS idx_waste_listings_category ON waste_listings(category_id);
CREATE INDEX IF NOT EXISTS idx_collection_requests_collector ON collection_requests(collector_id);
CREATE INDEX IF NOT EXISTS idx_material_listings_business ON material_listings(business_id);
