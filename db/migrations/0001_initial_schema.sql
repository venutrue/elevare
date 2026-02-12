BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- Utility trigger to keep updated_at current
-- =====================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Core identity and access tables
-- =====================================================
CREATE TABLE app_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT NOT NULL UNIQUE,
  phone TEXT,
  first_name TEXT NOT NULL,
  last_name TEXT,
  password_hash TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  last_login_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE user_roles (
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, role_id)
);

-- =====================================================
-- Organization and property model
-- =====================================================
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  organization_type TEXT NOT NULL CHECK (organization_type IN ('owner_group', 'operations', 'legal_partner', 'vendor')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE addresses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  line1 TEXT NOT NULL,
  line2 TEXT,
  landmark TEXT,
  city TEXT NOT NULL,
  district TEXT,
  state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'India',
  postal_code TEXT,
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE properties (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  property_code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  property_type TEXT NOT NULL CHECK (property_type IN ('apartment', 'independent_house', 'villa', 'bungalow', 'plot', 'commercial', 'agricultural_land')),
  usage_type TEXT NOT NULL CHECK (usage_type IN ('residential', 'commercial', 'mixed', 'agricultural')),
  address_id UUID REFERENCES addresses(id) ON DELETE SET NULL,
  purchase_date DATE,
  acquisition_value NUMERIC(14, 2),
  current_estimated_value NUMERIC(14, 2),
  occupancy_status TEXT NOT NULL DEFAULT 'vacant' CHECK (occupancy_status IN ('vacant', 'owner_occupied', 'tenant_occupied', 'under_renovation', 'under_dispute')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE property_owners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  ownership_type TEXT NOT NULL CHECK (ownership_type IN ('primary', 'joint', 'nominee', 'beneficiary')),
  ownership_percentage NUMERIC(5, 2) CHECK (ownership_percentage >= 0 AND ownership_percentage <= 100),
  start_date DATE,
  end_date DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_owner_dates CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_property_owners_property_id ON property_owners(property_id);
CREATE INDEX idx_property_owners_user_id ON property_owners(user_id);

-- =====================================================
-- Legal and compliance domain
-- =====================================================
CREATE TABLE legal_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  opened_by UUID REFERENCES app_users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES app_users(id) ON DELETE SET NULL,
  case_number TEXT UNIQUE,
  case_type TEXT NOT NULL CHECK (case_type IN ('tenancy_dispute', 'boundary_dispute', 'title_issue', 'poa_issue', 'inheritance', 'builder_default', 'association_issue', 'other')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'awaiting_client', 'resolved', 'closed')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  summary TEXT NOT NULL,
  details TEXT,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_legal_case_dates CHECK (closed_at IS NULL OR closed_at >= opened_at)
);

CREATE INDEX idx_legal_cases_property_id ON legal_cases(property_id);
CREATE INDEX idx_legal_cases_assigned_to ON legal_cases(assigned_to);
CREATE INDEX idx_legal_cases_status ON legal_cases(status);

CREATE TABLE legal_case_updates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  legal_case_id UUID NOT NULL REFERENCES legal_cases(id) ON DELETE CASCADE,
  author_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  update_type TEXT NOT NULL CHECK (update_type IN ('note', 'court_filing', 'hearing_update', 'negotiation', 'resolution', 'document_request')),
  content TEXT NOT NULL,
  is_visible_to_owner BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_legal_case_updates_case_id ON legal_case_updates(legal_case_id);

CREATE TABLE compliance_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  check_type TEXT NOT NULL CHECK (check_type IN ('oc_cc', 'mutation', 'khata_patta', 'tax', 'encumbrance', 'zoning', 'poa_validity', 'document_hygiene')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_review', 'completed', 'blocked')),
  due_date DATE,
  completed_at TIMESTAMPTZ,
  assigned_to UUID REFERENCES app_users(id) ON DELETE SET NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_compliance_checks_property_id ON compliance_checks(property_id);
CREATE INDEX idx_compliance_checks_status ON compliance_checks(status);

CREATE TABLE powers_of_attorney (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  owner_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  attorney_holder_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  poa_scope TEXT NOT NULL,
  registration_number TEXT,
  issued_on DATE NOT NULL,
  valid_until DATE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('draft', 'active', 'revoked', 'expired')),
  revoked_on DATE,
  revocation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_poa_dates CHECK (valid_until IS NULL OR valid_until >= issued_on),
  CONSTRAINT valid_revocation_date CHECK (revoked_on IS NULL OR revoked_on >= issued_on)
);

CREATE INDEX idx_poa_property_id ON powers_of_attorney(property_id);
CREATE INDEX idx_poa_owner_id ON powers_of_attorney(owner_id);

-- =====================================================
-- Property operations and tenancy
-- =====================================================
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  full_name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  kyc_reference TEXT,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tenancies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  lease_start DATE NOT NULL,
  lease_end DATE,
  monthly_rent NUMERIC(12, 2) NOT NULL,
  security_deposit NUMERIC(12, 2),
  payment_day_of_month SMALLINT CHECK (payment_day_of_month BETWEEN 1 AND 31),
  agreement_status TEXT NOT NULL DEFAULT 'active' CHECK (agreement_status IN ('draft', 'active', 'terminated', 'expired', 'under_dispute')),
  agreement_document_id UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_tenancy_dates CHECK (lease_end IS NULL OR lease_end >= lease_start)
);

CREATE INDEX idx_tenancies_property_id ON tenancies(property_id);
CREATE INDEX idx_tenancies_tenant_id ON tenancies(tenant_id);

CREATE TABLE rent_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenancy_id UUID NOT NULL REFERENCES tenancies(id) ON DELETE CASCADE,
  due_date DATE NOT NULL,
  amount_due NUMERIC(12, 2) NOT NULL,
  amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0,
  paid_on TIMESTAMPTZ,
  payment_status TEXT NOT NULL DEFAULT 'due' CHECK (payment_status IN ('due', 'partially_paid', 'paid', 'overdue', 'waived')),
  reference_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_rent_payments_tenancy_id ON rent_payments(tenancy_id);
CREATE INDEX idx_rent_payments_due_date ON rent_payments(due_date);

CREATE TABLE inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  inspector_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  inspection_type TEXT NOT NULL CHECK (inspection_type IN ('routine', 'handover', 'move_in', 'move_out', 'compliance', 'emergency')),
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'completed', 'cancelled')),
  scheduled_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  summary TEXT,
  risk_level TEXT CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_inspection_dates CHECK (completed_at IS NULL OR scheduled_at IS NULL OR completed_at >= scheduled_at)
);

CREATE INDEX idx_inspections_property_id ON inspections(property_id);
CREATE INDEX idx_inspections_status ON inspections(status);

CREATE TABLE inspection_media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  inspection_id UUID NOT NULL REFERENCES inspections(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video', 'document')),
  storage_key TEXT NOT NULL,
  caption TEXT,
  captured_at TIMESTAMPTZ,
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_inspection_media_inspection_id ON inspection_media(inspection_id);

CREATE TABLE maintenance_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  raised_by UUID REFERENCES app_users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES app_users(id) ON DELETE SET NULL,
  request_type TEXT NOT NULL CHECK (request_type IN ('plumbing', 'electrical', 'civil', 'cleaning', 'painting', 'security', 'other')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'waiting_parts', 'resolved', 'closed')),
  description TEXT NOT NULL,
  estimated_cost NUMERIC(12, 2),
  actual_cost NUMERIC(12, 2),
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_maintenance_requests_property_id ON maintenance_requests(property_id);
CREATE INDEX idx_maintenance_requests_status ON maintenance_requests(status);

-- =====================================================
-- Shared communication layer (web + mobile)
-- =====================================================
CREATE TABLE support_tickets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE SET NULL,
  opened_by UUID REFERENCES app_users(id) ON DELETE SET NULL,
  assigned_to UUID REFERENCES app_users(id) ON DELETE SET NULL,
  ticket_type TEXT NOT NULL CHECK (ticket_type IN ('general', 'legal', 'maintenance', 'billing', 'technical', 'emergency')),
  priority TEXT NOT NULL DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'waiting_client', 'resolved', 'closed')),
  subject TEXT NOT NULL,
  description TEXT,
  opened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_support_tickets_property_id ON support_tickets(property_id);
CREATE INDEX idx_support_tickets_status ON support_tickets(status);

CREATE TABLE ticket_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  message_body TEXT NOT NULL,
  is_internal BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ticket_messages_ticket_id ON ticket_messages(ticket_id);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  channel TEXT NOT NULL CHECK (channel IN ('in_app', 'email', 'sms', 'push', 'whatsapp')),
  notification_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  entity_type TEXT,
  entity_id UUID,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  sent_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_is_read ON notifications(is_read);

-- =====================================================
-- Financial structure
-- =====================================================
CREATE TABLE subscription_plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  billing_cycle TEXT NOT NULL CHECK (billing_cycle IN ('monthly', 'quarterly', 'yearly')),
  base_price NUMERIC(12, 2) NOT NULL,
  currency_code CHAR(3) NOT NULL DEFAULT 'INR',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE property_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  plan_id UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('trial', 'active', 'paused', 'cancelled', 'expired')),
  start_date DATE NOT NULL,
  end_date DATE,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT valid_subscription_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

CREATE INDEX idx_property_subscriptions_property_id ON property_subscriptions(property_id);

CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_subscription_id UUID REFERENCES property_subscriptions(id) ON DELETE SET NULL,
  invoice_number TEXT NOT NULL UNIQUE,
  issue_date DATE NOT NULL,
  due_date DATE NOT NULL,
  subtotal_amount NUMERIC(12, 2) NOT NULL,
  tax_amount NUMERIC(12, 2) NOT NULL DEFAULT 0,
  total_amount NUMERIC(12, 2) NOT NULL,
  amount_paid NUMERIC(12, 2) NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'issued', 'partially_paid', 'paid', 'void', 'overdue')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE invoice_line_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('subscription', 'legal_service', 'maintenance', 'inspection', 'other')),
  description TEXT NOT NULL,
  quantity NUMERIC(10, 2) NOT NULL DEFAULT 1,
  unit_price NUMERIC(12, 2) NOT NULL,
  line_total NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoice_line_items_invoice_id ON invoice_line_items(invoice_id);

-- =====================================================
-- Document vault and audit
-- =====================================================
CREATE TABLE documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID REFERENCES properties(id) ON DELETE CASCADE,
  owner_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  uploaded_by UUID REFERENCES app_users(id) ON DELETE SET NULL,
  document_type TEXT NOT NULL CHECK (document_type IN ('sale_deed', 'ec', 'tax_receipt', 'poa', 'rental_agreement', 'id_proof', 'legal_notice', 'court_order', 'inspection_report', 'other')),
  title TEXT NOT NULL,
  storage_key TEXT NOT NULL,
  mime_type TEXT,
  file_size_bytes BIGINT,
  checksum_sha256 TEXT,
  is_sensitive BOOLEAN NOT NULL DEFAULT TRUE,
  expires_on DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_documents_property_id ON documents(property_id);
CREATE INDEX idx_documents_document_type ON documents(document_type);

ALTER TABLE tenancies
  ADD CONSTRAINT fk_tenancies_agreement_document
  FOREIGN KEY (agreement_document_id) REFERENCES documents(id) ON DELETE SET NULL;

CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_actor_user_id ON audit_logs(actor_user_id);
CREATE INDEX idx_audit_logs_entity ON audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- =====================================================
-- Attach updated_at trigger to mutable tables
-- =====================================================
CREATE TRIGGER trg_app_users_set_updated_at BEFORE UPDATE ON app_users FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_roles_set_updated_at BEFORE UPDATE ON roles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_organizations_set_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_addresses_set_updated_at BEFORE UPDATE ON addresses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_properties_set_updated_at BEFORE UPDATE ON properties FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_property_owners_set_updated_at BEFORE UPDATE ON property_owners FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_legal_cases_set_updated_at BEFORE UPDATE ON legal_cases FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_compliance_checks_set_updated_at BEFORE UPDATE ON compliance_checks FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_powers_of_attorney_set_updated_at BEFORE UPDATE ON powers_of_attorney FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_tenants_set_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_tenancies_set_updated_at BEFORE UPDATE ON tenancies FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_rent_payments_set_updated_at BEFORE UPDATE ON rent_payments FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_inspections_set_updated_at BEFORE UPDATE ON inspections FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_maintenance_requests_set_updated_at BEFORE UPDATE ON maintenance_requests FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_support_tickets_set_updated_at BEFORE UPDATE ON support_tickets FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_notifications_set_updated_at BEFORE UPDATE ON notifications FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_subscription_plans_set_updated_at BEFORE UPDATE ON subscription_plans FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_property_subscriptions_set_updated_at BEFORE UPDATE ON property_subscriptions FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_invoices_set_updated_at BEFORE UPDATE ON invoices FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_documents_set_updated_at BEFORE UPDATE ON documents FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
