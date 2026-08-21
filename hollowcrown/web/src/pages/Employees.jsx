import React, { useEffect, useState, useCallback } from 'react';
import { Link, useSearchParams } from 'react-router-dom';
import { api } from '../api/client';
import StatusBadge from '../components/StatusBadge';

const STATUSES    = ['', 'active', 'on-leave', 'terminated'];
const STATUS_LABELS = { '': 'All statuses', active: 'Active', 'on-leave': 'On leave', terminated: 'Terminated' };

export default function Employees() {
  const [searchParams, setSearchParams] = useSearchParams();
  const [data, setData]         = useState(null);
  const [departments, setDepts] = useState([]);
  const [loading, setLoading]   = useState(true);

  const search     = searchParams.get('search')     || '';
  const department = searchParams.get('department') || '';
  const status     = searchParams.get('status')     || '';
  const offset     = parseInt(searchParams.get('offset') || '0', 10);
  const limit      = 25;

  const fetch = useCallback(() => {
    setLoading(true);
    const params = { limit, offset };
    if (search)     params.search     = search;
    if (department) params.department = department;
    if (status)     params.status     = status;
    api.getEmployees(params)
      .then(d => { setData(d); setLoading(false); })
      .catch(() => setLoading(false));
  }, [search, department, status, offset]);

  useEffect(() => { fetch(); }, [fetch]);
  useEffect(() => { api.getDepartments().then(setDepts); }, []);

  function setParam(key, val) {
    const next = new URLSearchParams(searchParams);
    if (val) next.set(key, val); else next.delete(key);
    next.delete('offset');
    setSearchParams(next);
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold text-gray-900">Employees</h1>
          {data && <p className="text-sm text-gray-500 mt-0.5">{data.total} total</p>}
        </div>
        <Link
          to="/employees/new"
          className="bg-crown-700 hover:bg-crown-800 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors"
        >
          + New employee
        </Link>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3">
        <input
          type="search"
          placeholder="Search name, email, ID…"
          value={search}
          onChange={e => setParam('search', e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm w-64 focus:outline-none focus:ring-2 focus:ring-crown-500"
        />
        <select
          value={department}
          onChange={e => setParam('department', e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-crown-500"
        >
          <option value="">All departments</option>
          {departments.map(d => <option key={d} value={d}>{d}</option>)}
        </select>
        <select
          value={status}
          onChange={e => setParam('status', e.target.value)}
          className="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-crown-500"
        >
          {STATUSES.map(s => <option key={s} value={s}>{STATUS_LABELS[s]}</option>)}
        </select>
      </div>

      {/* Table */}
      <div className="bg-white rounded-xl border border-gray-200 overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-gray-500 text-sm">Loading…</div>
        ) : !data?.resources?.length ? (
          <div className="p-8 text-center text-gray-500 text-sm">No employees found.</div>
        ) : (
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-gray-100 bg-gray-50 text-xs text-gray-500 uppercase tracking-wide">
                <th className="px-5 py-3 text-left font-medium">ID</th>
                <th className="px-5 py-3 text-left font-medium">Name</th>
                <th className="px-5 py-3 text-left font-medium hidden sm:table-cell">Department</th>
                <th className="px-5 py-3 text-left font-medium hidden md:table-cell">Title</th>
                <th className="px-5 py-3 text-left font-medium">Status</th>
                <th className="px-5 py-3 text-left font-medium hidden lg:table-cell">Hire date</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {data.resources.map(e => (
                <tr key={e.id} className="hover:bg-gray-50 transition-colors">
                  <td className="px-5 py-3 font-mono text-xs text-gray-500">{e.employeeId}</td>
                  <td className="px-5 py-3">
                    <Link to={`/employees/${e.id}`} className="font-medium text-crown-700 hover:underline">
                      {e.firstName} {e.lastName}
                    </Link>
                    <p className="text-xs text-gray-400">{e.email}</p>
                  </td>
                  <td className="px-5 py-3 text-gray-600 hidden sm:table-cell">{e.department}</td>
                  <td className="px-5 py-3 text-gray-600 hidden md:table-cell">{e.jobTitle}</td>
                  <td className="px-5 py-3"><StatusBadge status={e.status} /></td>
                  <td className="px-5 py-3 text-gray-500 hidden lg:table-cell">{e.hireDate?.split('T')[0]}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {/* Pagination */}
      {data && data.total > limit && (
        <div className="flex items-center justify-between text-sm text-gray-600">
          <span>Showing {offset + 1}–{Math.min(offset + limit, data.total)} of {data.total}</span>
          <div className="flex gap-2">
            <button
              disabled={offset === 0}
              onClick={() => setParam('offset', Math.max(0, offset - limit))}
              className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >← Previous</button>
            <button
              disabled={offset + limit >= data.total}
              onClick={() => setParam('offset', offset + limit)}
              className="px-3 py-1.5 border border-gray-300 rounded-lg disabled:opacity-40 hover:bg-gray-50"
            >Next →</button>
          </div>
        </div>
      )}
    </div>
  );
}
