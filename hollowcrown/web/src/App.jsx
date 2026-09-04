import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Employees from './pages/Employees';
import EmployeeDetail from './pages/EmployeeDetail';
import NewEmployee from './pages/NewEmployee';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard"         element={<Dashboard />} />
          <Route path="employees"         element={<Employees />} />
          <Route path="employees/new"     element={<NewEmployee />} />
          <Route path="employees/:id"     element={<EmployeeDetail />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
