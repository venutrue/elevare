import { useState } from 'react';
import { Search, Plus, HardHat, Loader2, ChevronDown, ChevronRight, CheckCircle2, Circle, Clock, IndianRupee } from 'lucide-react';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/Card';
import { Button } from '@/components/ui/Button';
import { Badge, StatusBadge } from '@/components/ui/Badge';
import { Table, TableHeader, TableBody, TableRow, TableHead, TableCell } from '@/components/ui/Table';
import { Modal } from '@/components/ui/Modal';
import { Input, Select, Textarea } from '@/components/ui/Input';
import { EmptyState } from '@/components/ui/EmptyState';
import useApi from '@/hooks/useApi';
import api from '@/api/client';

interface ConstructionProject { id: string; property_id: string; property_name: string; project_type: string; title: string; description: string | null; status: string; estimated_budget: number | null; actual_spend: number | null; start_date: string | null; target_end_date: string | null; actual_end_date: string | null; milestones_completed: number; milestones_total: number; created_at: string; }
interface Milestone { id: string; project_id: string; title: string; description: string | null; status: string; due_date: string | null; completed_date: string | null; order_index: number; }
interface PaginatedResponse<T> { data: T[]; total: number; }
interface Property { id: string; name: string; }

const PROJECT_TYPES = [{ value: 'new_build', label: 'New Build' }, { value: 'renovation', label: 'Renovation' }, { value: 'extension', label: 'Extension' }, { value: 'interior', label: 'Interior' }, { value: 'exterior', label: 'Exterior' }, { value: 'landscaping', label: 'Landscaping' }, { value: 'infrastructure', label: 'Infrastructure' }];
const PROJECT_STATUSES = [{ value: '', label: 'All Statuses' }, { value: 'planning', label: 'Planning' }, { value: 'in_progress', label: 'In Progress' }, { value: 'on_hold', label: 'On Hold' }, { value: 'completed', label: 'Completed' }, { value: 'cancelled', label: 'Cancelled' }];

function fmtCurrency(a: number | null) { if (a == null) return '-'; return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(a); }
function fmtDate(d: string | null) { if (!d) return '-'; return new Date(d).toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' }); }

export default function Construction() {
  const [search, setSearch] = useState('');
  const [filterStatus, setFilterStatus] = useState('');
  const [showAddModal, setShowAddModal] = useState(false);
  const [expandedRow, setExpandedRow] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [form, setForm] = useState({ property_id: '', project_type: 'renovation', title: '', description: '', estimated_budget: '', start_date: '', target_end_date: '' });

  const params: Record<string, string> = {}; if (filterStatus) params.status = filterStatus;
  const { data: projData, loading, refetch } = useApi<PaginatedResponse<ConstructionProject>>(() => api.get('/construction', params), [filterStatus]);
  const { data: properties } = useApi<PaginatedResponse<Property>>(() => api.get('/properties', { limit: '200' }), []);
  const { data: milestones, refetch: refetchMs } = useApi<Milestone[]>(() => expandedRow ? api.get(`/construction/${expandedRow}/milestones`) : Promise.resolve([]), [expandedRow]);

  const projects = projData?.data || [];
  const filtered = projects.filter((p) => { if (!search) return true; const q = search.toLowerCase(); return p.property_name.toLowerCase().includes(q) || p.title.toLowerCase().includes(q); });
  const propertyOptions = (properties?.data || []).map((p) => ({ value: p.id, label: p.name }));

  const handleSubmit = async () => {
    if (!form.property_id || !form.title) return; setSubmitting(true);
    try { await api.post('/construction', { property_id: form.property_id, project_type: form.project_type, title: form.title, description: form.description || undefined, estimated_budget: form.estimated_budget ? parseFloat(form.estimated_budget) : undefined, start_date: form.start_date || undefined, target_end_date: form.target_end_date || undefined }); setShowAddModal(false); setForm({ property_id: '', project_type: 'renovation', title: '', description: '', estimated_budget: '', start_date: '', target_end_date: '' }); refetch(); } catch {} finally { setSubmitting(false); }
  };
  const toggleMs = async (ms: Milestone) => { try { const ns = ms.status === 'completed' ? 'pending' : 'completed'; await api.put(`/construction/milestones/${ms.id}`, { status: ns, completed_date: ns === 'completed' ? new Date().toISOString().split('T')[0] : null }); refetchMs(); refetch(); } catch {} };

  if (loading) { return (<div className="space-y-6"><div className="flex items-center justify-between"><div><div className="h-7 w-52 bg-gray-200 rounded animate-pulse" /></div><div className="h-10 w-36 bg-gray-200 rounded-lg animate-pulse" /></div><div className="bg-white rounded-xl border p-6 animate-pulse"><div className="space-y-4">{Array.from({ length: 4 }).map((_, i) => <div key={i} className="h-12 bg-gray-100 rounded" />)}</div></div></div>); }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between"><div><h1 className="text-2xl font-bold text-gray-900">Construction Projects</h1><p className="text-sm text-gray-500 mt-1">Manage construction and renovation projects</p></div><Button onClick={() => setShowAddModal(true)}><Plus className="w-4 h-4 mr-2" />Add Project</Button></div>
      <Card><CardContent><div className="flex flex-col sm:flex-row gap-4"><div className="relative flex-1"><Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" /><input type="text" placeholder="Search projects..." value={search} onChange={(e) => setSearch(e.target.value)} className="w-full pl-10 pr-4 py-2 border border-gray-300 rounded-lg text-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 focus:outline-none" /></div>
        <select value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)} className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:border-indigo-500 focus:ring-2 focus:ring-indigo-500/20 focus:outline-none">{PROJECT_STATUSES.map((s) => <option key={s.value} value={s.value}>{s.label}</option>)}</select>
      </div></CardContent></Card>

      <Card>{filtered.length === 0 ? <EmptyState icon={<HardHat className="w-8 h-8 text-gray-400" />} title="No construction projects" description="Create a new project to get started." action={<Button onClick={() => setShowAddModal(true)} size="sm"><Plus className="w-4 h-4 mr-1" /> Add Project</Button>} /> : (
        <Table><TableHeader><TableRow><TableHead className="w-10" /><TableHead>Property</TableHead><TableHead>Title</TableHead><TableHead>Type</TableHead><TableHead>Status</TableHead><TableHead>Budget</TableHead><TableHead>Timeline</TableHead><TableHead>Progress</TableHead></TableRow></TableHeader>
          <TableBody>{filtered.map((proj) => { const isExp = expandedRow === proj.id; const pct = proj.milestones_total > 0 ? Math.round((proj.milestones_completed / proj.milestones_total) * 100) : 0; return (<>
            <TableRow key={proj.id} className="cursor-pointer" onClick={() => setExpandedRow(isExp ? null : proj.id)}>
              <TableCell>{isExp ? <ChevronDown className="w-4 h-4 text-gray-400" /> : <ChevronRight className="w-4 h-4 text-gray-400" />}</TableCell>
              <TableCell className="font-medium">{proj.property_name}</TableCell><TableCell>{proj.title}</TableCell>
              <TableCell><Badge color="indigo">{proj.project_type.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())}</Badge></TableCell>
              <TableCell><StatusBadge status={proj.status} /></TableCell><TableCell>{fmtCurrency(proj.estimated_budget)}</TableCell>
              <TableCell><div className="text-xs text-gray-500">{fmtDate(proj.start_date)} - {fmtDate(proj.target_end_date)}</div></TableCell>
              <TableCell><div className="flex items-center gap-2 min-w-[120px]"><div className="flex-1 bg-gray-200 rounded-full h-2"><div className="bg-indigo-600 h-2 rounded-full transition-all" style={{ width: `${pct}%` }} /></div><span className="text-xs text-gray-500 w-16 text-right">{proj.milestones_completed}/{proj.milestones_total}</span></div></TableCell>
            </TableRow>
            {isExp && <tr key={`${proj.id}-exp`}><td colSpan={8} className="px-6 py-4 bg-gray-50">
              <div className="mb-4"><h4 className="text-sm font-semibold text-gray-700 mb-3 flex items-center gap-2"><IndianRupee className="w-4 h-4" />Budget Comparison</h4><div className="grid grid-cols-2 gap-4 max-w-md"><div className="bg-blue-50 rounded-lg p-3 text-center"><p className="text-xs text-blue-600 uppercase font-medium">Estimated</p><p className="text-lg font-bold text-blue-700">{fmtCurrency(proj.estimated_budget)}</p></div><div className="bg-green-50 rounded-lg p-3 text-center"><p className="text-xs text-green-600 uppercase font-medium">Actual Spend</p><p className="text-lg font-bold text-green-700">{fmtCurrency(proj.actual_spend)}</p></div></div></div>
              <h4 className="text-sm font-semibold text-gray-700 mb-3">Milestones</h4>
              {!milestones || milestones.length === 0 ? <p className="text-sm text-gray-400">No milestones defined yet.</p> : <div className="space-y-2">{milestones.sort((a, b) => a.order_index - b.order_index).map((ms) => (
                <div key={ms.id} className="flex items-center gap-3 bg-white rounded-lg px-4 py-2 border border-gray-200">
                  <button onClick={(e) => { e.stopPropagation(); toggleMs(ms); }} className="flex-shrink-0">{ms.status === 'completed' ? <CheckCircle2 className="w-5 h-5 text-green-500" /> : ms.status === 'in_progress' ? <Clock className="w-5 h-5 text-blue-500" /> : <Circle className="w-5 h-5 text-gray-300" />}</button>
                  <div className="flex-1"><p className={`text-sm ${ms.status === 'completed' ? 'line-through text-gray-400' : 'text-gray-700'}`}>{ms.title}</p>{ms.description && <p className="text-xs text-gray-400">{ms.description}</p>}</div>
                  {ms.due_date && <span className="text-xs text-gray-400">{fmtDate(ms.due_date)}</span>}<StatusBadge status={ms.status} />
                </div>
              ))}</div>}
            </td></tr>}
          </>); })}</TableBody></Table>
      )}</Card>

      <Modal open={showAddModal} onClose={() => setShowAddModal(false)} title="Add Construction Project" size="lg">
        <div className="space-y-4">
          <Select label="Property" value={form.property_id} onChange={(e) => setForm({ ...form, property_id: e.target.value })} options={propertyOptions} placeholder="Select a property" />
          <Input label="Title" placeholder="Project title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
          <Select label="Project Type" value={form.project_type} onChange={(e) => setForm({ ...form, project_type: e.target.value })} options={PROJECT_TYPES} />
          <Textarea label="Description" placeholder="Project description..." value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} />
          <Input label="Estimated Budget (INR)" type="number" placeholder="0" value={form.estimated_budget} onChange={(e) => setForm({ ...form, estimated_budget: e.target.value })} />
          <div className="grid grid-cols-2 gap-4"><Input label="Start Date" type="date" value={form.start_date} onChange={(e) => setForm({ ...form, start_date: e.target.value })} /><Input label="Target End Date" type="date" value={form.target_end_date} onChange={(e) => setForm({ ...form, target_end_date: e.target.value })} /></div>
          <div className="flex justify-end gap-3 pt-4 border-t"><Button variant="outline" onClick={() => setShowAddModal(false)}>Cancel</Button><Button onClick={handleSubmit} disabled={submitting || !form.property_id || !form.title}>{submitting ? <Loader2 className="w-4 h-4 mr-2 animate-spin" /> : <Plus className="w-4 h-4 mr-2" />}Create Project</Button></div>
        </div>
      </Modal>
    </div>
  );
}
