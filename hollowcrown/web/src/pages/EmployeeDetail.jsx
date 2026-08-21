import React, { useEffect, useState } from 'react';
import { useParams, useNavigate, Link } from 'react-router-dom';
import { api } from '../api/client';
import StatusBadge from '../components/StatusBadge';
import Modal from '../components/Modal';

function Field({ label, children }) {
  return (
    <div>
      <p className="text-xs text-gray-500 mb-0.5">{label}</p>
      <p className="text-sm text-gray-900">{children || <span className="text-gray-400">—</span>}</p>
    </div>
  );
}

function EditableField({ label, name, value, onChange, type = 'text', options }) {
  if (options) return (
    <div>
      <label className="text-xs text-gray-500 block mb-0.5">{label}</label>
      <select
        name={name}
        value={value}
        onChange={onChange}
        className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-crown-500"
      >
        {options.map(o => <option key={o} value={o}>{o}</option>)}
      </select>
    </div>
  );
  return (
    <div>
      <label className="text-xs text-gray-500 block mb-0.5">{label}</label>
      <input
        type={type}
        name={name}
        value={value}
        onChange={onChange}
        className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-crown-500"
      />
    </div>
  );
}

export default function EmployeeDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [employee, setEmployee] = useState(null);
  const [departments, setDepts] = useState([]);
  const [editing, setEditing]   = useState(false);
  const [form, setForm]         = useState({});
  const [modal, setModal]       = useState(null); // 'terminate' | 'status'
  const [saving, setSaving]     = useState(false);
  const [error, setError]       = useState(null);

  useEffect(() => {
    api.getEmployee(id).then(e => { setEmployee(e); setForm(e); }).catch(e => setError(e.message));
    api.getDepartments().then(setDepts);
  }, [id]);

  function handleChange(e) {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }));
  }

  async function handleSave() {
    setSaving(true);
    try {
      const updated = await api.updateEmployee(id, {
        firstName: form.firstName, lastName: form.lastName,
        email: form.email, phone: form.phone,
        department: form.department, jobTitle: form.jobTitle,
        hireDate: form.hireDate,
      });
      setEmployee(updated); setEditing(false);
    } catch (e) { setError(e.message); }
    setSaving(false);
  }

  async function handleTerminate(date) {
    setSaving(true);
    try {
      const updated = await api.terminate(id, { terminationDate: date });
      setEmployee(updated); setModal(null);
    } catch (e) { setError(e.message); }
    setSaving(false);
  }

  async function handleSetStatus(status) {
    setSaving(true);
    try {
      const updated = await api.setStatus(id, { status });
      setEmployee(updated); setModal(null);
    } catch (e) { setError(e.message); }
    setSaving(false);
  }

  if (error) return <p className="text-red-600">{error}</p>;
  if (!employee) return <p className="text-gray-500">Loading…</p>;

  return (
    <div className="space-y-6 max-w-3xl">
      {/* Breadcrumb */}
      <p className="text-sm text-gray-500">
        <Link to="/employees" className="hover:text-crown-700">Employees</Link>
        <span className="mx-2">›</span>
        <span className="text-gray-900 font-medium">{employee.firstName} {employee.lastName}</span>
      </p>

      {/* Header */}
      <div className="flex items-start justify-between gap-4">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-full bg-crown-100 text-crown-700 flex items-center justify-center text-xl font-semibold select-none">
            {employee.firstName[0]}{employee.lastName[0]}
          </div>
          <div>
            <h1 className="text-2xl font-semibold text-gray-900">{employee.firstName} {employee.lastName}</h1>
            <p className="text-sm text-gray-500">{employee.jobTitle} · {employee.department}</p>
            <p className="text-xs text-gray-400 font-mono mt-0.5">{employee.employeeId}</p>
          </div>
        </div>
        <div className="flex items-center gap-2 shrink-0">
          <StatusBadge status={employee.status} />
          {!editing && (
            <button
              onClick={() => setEditing(true)}
              className="text-sm border border-gray-300 px-3 py-1.5 rounded-lg hover:bg-gray-50"
            >Edit</button>
          )}
        </div>
      </div>

      {/* Details card */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        {editing ? (
          <div className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <EditableField label="First name"  name="firstName"  value={form.firstName}  onChange={handleChange} />
              <EditableField label="Last name"   name="lastName"   value={form.lastName}   onChange={handleChange} />
              <EditableField label="Email"       name="email"      value={form.email}      onChange={handleChange} type="email" />
              <EditableField label="Phone"       name="phone"      value={form.phone||''}  onChange={handleChange} />
              <EditableField label="Department"  name="department" value={form.department} onChange={handleChange} options={departments} />
              <EditableField label="Job title"   name="jobTitle"   value={form.jobTitle}   onChange={handleChange} />
              <EditableField label="Hire date"   name="hireDate"   value={form.hireDate?.split('T')[0]||''} onChange={handleChange} type="date" />
            </div>
            <div className="flex gap-2 pt-2">
              <button
                onClick={handleSave}
                disabled={saving}
                className="bg-crown-700 hover:bg-crown-800 text-white text-sm font-medium px-4 py-2 rounded-lg disabled:opacity-50"
              >{saving ? 'Saving…' : 'Save changes'}</button>
              <button
                onClick={() => { setEditing(false); setForm(employee); }}
                className="text-sm border border-gray-300 px-4 py-2 rounded-lg hover:bg-gray-50"
              >Cancel</button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-5">
            <Field label="Email">{employee.email}</Field>
            <Field label="Phone">{employee.phone}</Field>
            <Field label="Hire date">{employee.hireDate?.split('T')[0]}</Field>
            <Field label="Department">{employee.department}</Field>
            <Field label="Job title">{employee.jobTitle}</Field>
            <Field label="Manager">{employee.managerName}</Field>
            {employee.terminationDate && (
              <Field label="Termination date">{employee.terminationDate?.split('T')[0]}</Field>
            )}
          </div>
        )}
      </div>

      {/* Actions */}
      {!editing && employee.status !== 'terminated' && (
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-3">Actions</h2>
          <div className="flex flex-wrap gap-2">
            {employee.status === 'active' && (
              <button
                onClick={() => setModal('leave')}
                className="text-sm border border-yellow-300 text-yellow-700 px-3 py-1.5 rounded-lg hover:bg-yellow-50"
              >Set on leave</button>
            )}
            {employee.status === 'on-leave' && (
              <button
                onClick={() => handleSetStatus('active')}
                className="text-sm border border-green-300 text-green-700 px-3 py-1.5 rounded-lg hover:bg-green-50"
              >Restore to active</button>
            )}
            <button
              onClick={() => setModal('terminate')}
              className="text-sm border border-red-300 text-red-600 px-3 py-1.5 rounded-lg hover:bg-red-50"
            >Terminate</button>
          </div>
        </div>
      )}

      {/* Terminate modal */}
      {modal === 'terminate' && (
        <TerminateModal
          onConfirm={handleTerminate}
          onClose={() => setModal(null)}
          saving={saving}
        />
      )}

      {/* Set on-leave modal */}
      {modal === 'leave' && (
        <Modal title="Set employee on leave" onClose={() => setModal(null)}>
          <p className="text-sm text-gray-600 mb-4">
            The employee will be marked as <strong>on leave</strong>. You can restore them to active at any time.
          </p>
          <div className="flex gap-2">
            <button
              onClick={() => handleSetStatus('on-leave')}
              disabled={saving}
              className="flex-1 bg-yellow-600 hover:bg-yellow-700 text-white text-sm font-medium py-2 rounded-lg disabled:opacity-50"
            >{saving ? 'Saving…' : 'Confirm'}</button>
            <button onClick={() => setModal(null)} className="flex-1 border border-gray-300 text-sm py-2 rounded-lg hover:bg-gray-50">
              Cancel
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}

function TerminateModal({ onConfirm, onClose, saving }) {
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  return (
    <Modal title="Terminate employee" onClose={onClose}>
      <p className="text-sm text-gray-600 mb-4">This action will mark the employee as terminated.</p>
      <div className="mb-4">
        <label className="text-xs text-gray-500 block mb-1">Termination date</label>
        <input
          type="date"
          value={date}
          onChange={e => setDate(e.target.value)}
          className="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-red-400"
        />
      </div>
      <div className="flex gap-2">
        <button
          onClick={() => onConfirm(date)}
          disabled={saving}
          className="flex-1 bg-red-600 hover:bg-red-700 text-white text-sm font-medium py-2 rounded-lg disabled:opacity-50"
        >{saving ? 'Saving…' : 'Terminate'}</button>
        <button onClick={onClose} className="flex-1 border border-gray-300 text-sm py-2 rounded-lg hover:bg-gray-50">
          Cancel
        </button>
      </div>
    </Modal>
  );
}
