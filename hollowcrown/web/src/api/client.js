const BASE = import.meta.env.VITE_API_URL || '';

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options.headers },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw Object.assign(new Error(err.message || res.statusText), { status: res.status, data: err });
  }
  if (res.status === 204) return null;
  return res.json();
}

export const api = {
  getStats:      ()         => request('/api/stats'),
  getEmployees:  (params)   => request('/api/employees?' + new URLSearchParams(params).toString()),
  getEmployee:   (id)       => request(`/api/employees/${id}`),
  createEmployee:(data)     => request('/api/employees', { method: 'POST', body: data }),
  updateEmployee:(id, data) => request(`/api/employees/${id}`, { method: 'PUT', body: data }),
  terminate:     (id, data) => request(`/api/employees/${id}/terminate`, { method: 'POST', body: data }),
  setStatus:     (id, data) => request(`/api/employees/${id}/set-status`, { method: 'POST', body: data }),
  getDepartments:()         => request('/api/departments'),
};
