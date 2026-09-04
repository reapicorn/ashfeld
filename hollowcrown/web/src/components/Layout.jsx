import React from 'react';
import { Outlet, NavLink, useLocation } from 'react-router-dom';

const nav = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/employees', label: 'Employees' },
];

export default function Layout() {
  return (
    <div className="min-h-screen flex flex-col">
      {/* Top bar */}
      <header className="bg-crown-800 text-white shadow-md">
        <div className="max-w-7xl mx-auto px-6 h-14 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <span className="text-crown-200 text-xl font-light tracking-widest select-none">◇</span>
            <span className="font-semibold text-lg tracking-wide">hollowcrown</span>
            <span className="text-crown-300 text-xs font-normal ml-1 hidden sm:inline">HR System</span>
          </div>
          <nav className="flex gap-1">
            {nav.map(({ to, label }) => (
              <NavLink
                key={to}
                to={to}
                className={({ isActive }) =>
                  `px-4 py-1.5 rounded text-sm font-medium transition-colors ` +
                  (isActive
                    ? 'bg-crown-600 text-white'
                    : 'text-crown-200 hover:bg-crown-700 hover:text-white')
                }
              >
                {label}
              </NavLink>
            ))}
          </nav>
        </div>
      </header>

      {/* Content */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-6 py-8">
        <Outlet />
      </main>

      <footer className="text-center text-xs text-gray-400 py-4 border-t border-gray-200">
        hollowcrown · fictional HR system for integration practice
      </footer>
    </div>
  );
}
