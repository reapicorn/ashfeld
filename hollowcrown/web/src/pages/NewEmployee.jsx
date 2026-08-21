import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/client';

function Field({ label, children, required }) {
  return (
    <div>
      <label className="text-xs text-gray-500 block mb-1">
        {label}{required && <span className="text-red-500 ml-0.5">*</span>}
      </label>
      {children}
    </div>
  );
}

export default function NewEmployee() {
  const navigate = useNavigate();
  const [departments, setDepts] = useState([]);
  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '', phone: '',
    department: 'Engineering', jobTitle: '', hireDate: new Date().toISOString().split('T')[0],
  });
  const [saving, setSaving] = useState(false);
  const [error, setError]   = useState(null);

  useEffect(() => { api.getDepartments().then(d => { setDepts(d); }); }, []);

  function handleChange(e) {
    setForm(f => ({ ...f, [e.target.name]: e.target.value }));
  }

  async function handleSubmit(e) {
    e.preventDefault();
    if (!form.firstName || !form.lastName || !form.email || !form.jobTitle || !form.hireDate) {
      setError('Please fill in all required fields.');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const created = await api.createEmployee(form);
      navigate(`/employees/${created.id}`);
    } catch (err) {
      setError(err.data?.message || err.message);
      setSaving(false);
    }
  }

  const inputCls = 'w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-crown-500';

  return (
    <div className="max-w-2xl space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">New employee</h1>
        <p className="text-sm text-gray-500 mt-1">Add a new employee to hollowcrown.</p>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-xl border border-gray-200 p-6 space-y-5">
        <div className="grid grid-cols-2 gap-4">
          <Field label="First name" required>
            <input name="firstName" value={form.firstName} onChange={handleChange} className={inputCls} />
          </Field>
          <Field label="Last name" required>
            <input name="lastName" value={form.lastName} onChange={handleChange} className={inputCls} />
          </Field>
          <Field label="Email" required>
            <input name="email" type="email" value={form.email} onChange={handleChange} className={inputCls} />
          </Field>
          <Field label="Phone">
            <input name="phone" value={form.phone} onChange={handleChange} className={inputCls} placeholder="+1-555-…" />
          </Field>
          <Field label="Department" required>
            <select name="department" value={form.department} onChange={handleChange} className={inputCls}>
              {departments.map(d => <option key={d} value={d}>{d}</option>)}
            </select>
          </Field>
          <Field label="Job title" required>
            <input name="jobTitle" value={form.jobTitle} onChange={handleChange} className={inputCls} />
          </Field>
          <Field label="Hire date" required>
            <input name="hireDate" type="date" value={form.hireDate} onChange={handleChange} className={inputCls} />
          </Field>
        </div>

        {error && <p className="text-sm text-red-600">{error}</p>}

        <div className="flex gap-3 pt-1">
          <button
            type="submit"
            disabled={saving}
            className="bg-crown-700 hover:bg-crown-800 text-white text-sm font-medium px-5 py-2 rounded-lg disabled:opacity-50"
          >{saving ? 'Creating…' : 'Create employee'}</button>
          <button
            type="button"
            onClick={() => navigate('/employees')}
            className="text-sm border border-gray-300 px-5 py-2 rounded-lg hover:bg-gray-50"
          >Cancel</button>
        </div>
      </form>
    </div>
  );
}
