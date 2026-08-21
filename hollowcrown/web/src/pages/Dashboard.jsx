import React, { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api/client';
import StatusBadge from '../components/StatusBadge';

function StatCard({ label, value, color }) {
  return (
    <div className="bg-white rounded-xl border border-gray-200 p-5 flex flex-col gap-1">
      <span className="text-sm text-gray-500">{label}</span>
      <span className={`text-3xl font-bold ${color}`}>{value}</span>
    </div>
  );
}

export default function Dashboard() {
  const [stats, setStats] = useState(null);
  const [error, setError] = useState(null);

  useEffect(() => {
    api.getStats().then(setStats).catch(e => setError(e.message));
  }, []);

  if (error) return <p className="text-red-600">{error}</p>;
  if (!stats) return <p className="text-gray-500">Loading…</p>;

  const { counts, byDepartment, recentHires } = stats;

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold text-gray-900">Dashboard</h1>
        <p className="text-sm text-gray-500 mt-1">Workforce overview</p>
      </div>

      {/* Stat cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <StatCard label="Total employees"  value={counts.total}      color="text-gray-900" />
        <StatCard label="Active"           value={counts.active}     color="text-green-600" />
        <StatCard label="On leave"         value={counts.onLeave}    color="text-yellow-600" />
        <StatCard label="Terminated"       value={counts.terminated} color="text-red-600" />
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* By department */}
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Active headcount by department</h2>
          <div className="space-y-2">
            {byDepartment.map(({ department, count }) => (
              <div key={department} className="flex items-center gap-3">
                <span className="text-sm text-gray-600 w-28 shrink-0">{department}</span>
                <div className="flex-1 bg-gray-100 rounded-full h-2">
                  <div
                    className="bg-crown-500 h-2 rounded-full"
                    style={{ width: `${Math.round((count / counts.active) * 100)}%` }}
                  />
                </div>
                <span className="text-sm font-medium text-gray-700 w-6 text-right">{count}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Recent hires */}
        <div className="bg-white rounded-xl border border-gray-200 p-5">
          <h2 className="text-sm font-semibold text-gray-700 mb-4">Recent additions</h2>
          <div className="divide-y divide-gray-100">
            {recentHires.map(e => (
              <Link
                key={e.id}
                to={`/employees/${e.id}`}
                className="flex items-center justify-between py-2.5 hover:bg-gray-50 -mx-2 px-2 rounded"
              >
                <div>
                  <p className="text-sm font-medium text-gray-900">{e.first_name} {e.last_name}</p>
                  <p className="text-xs text-gray-500">{e.job_title} · {e.department}</p>
                </div>
                <StatusBadge status={e.status} />
              </Link>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
